(in-package #:cl-nes)

(defun %same-page-p (left right)
  (= (logand left #xFF00)
     (logand right #xFF00)))

(defun %signed-byte-8 (value)
  (if (logbitp 7 value)
      (- value #x100)
      value))

(defun %read-vector-word (bus low-address)
  (logior (bus-read bus low-address)
          (ash (bus-read bus (1+ low-address)) 8)))

(defun %interrupt-vector-address (type)
  (or (cdr (assoc type +cpu-interrupt-vectors+))
      (error "Unknown interrupt type: ~S" type)))

(defun %branch-target (pc offset)
  (logand (+ pc (%signed-byte-8 offset)) #xFFFF))

(defun %branch-cycle-count (page-crossed-p)
  (if page-crossed-p 4 3))

(defun %branch-fixup-address (old-pc new-pc)
  (logior (logand old-pc #xFF00)
          (logand new-pc #x00FF)))

(defun %branch! (cpu bus condition)
  (let ((offset (%fetch-byte cpu bus)))
    (if condition
        (let* ((old-pc (cpu-pc cpu))
               (new-pc (%branch-target old-pc offset))
               (page-crossed-p (not (%same-page-p old-pc new-pc))))
          (bus-read bus old-pc)
          (when page-crossed-p
            (bus-read bus (%branch-fixup-address old-pc new-pc)))
          (setf (cpu-pc cpu) new-pc)
          (unless page-crossed-p
            (setf (cpu-irq-poll-delay cpu) t))
          (%branch-cycle-count page-crossed-p))
        2)))

(defun %jump-indirect (cpu bus)
  (let* ((pointer (%fetch-word cpu bus))
         (low (bus-read bus pointer))
         (high-address (logior (logand pointer #xFF00)
                               (logand (1+ pointer) #xFF)))
         (high (bus-read bus high-address)))
    (setf (cpu-pc cpu) (logior low (ash high 8)))
    5))

(defun cpu-reset! (cpu bus)
  (%apply-cpu-state-specs! cpu +cpu-reset-state-specs+)
  (setf (cpu-pc cpu) (%read-vector-word bus +cpu-reset-vector-address+))
  (incf (cpu-cycles cpu) 7)
  cpu)

(defun %interrupt-vector-type (type nmi-poll)
  (if (and (eq type :irq)
           nmi-poll
           (funcall nmi-poll))
      :nmi
      type))

(defun %interrupt-deliverable-p (cpu type force-p)
  (or (eq type :nmi)
      (and (eq type :irq)
           (or force-p
               (not (%flag-set-p cpu +flag-interrupt-disable+))))))

(defun cpu-interrupt! (cpu bus type &optional force-p nmi-poll)
  (when (%interrupt-deliverable-p cpu type force-p)
    ;; An interrupt response is a seven-cycle instruction.  The first two
    ;; cycles are discarded reads from the current PC; keeping them as bus
    ;; accesses matters for PPU/APU timing and mapper side effects.
    (bus-read bus (cpu-pc cpu))
    (bus-read bus (cpu-pc cpu))
    (%push-word! cpu bus (cpu-pc cpu))
    (%push-byte! cpu bus (%status-for-stack cpu nil))
    (%set-flag! cpu +flag-interrupt-disable+ t)
    ;; An NMI edge observed during an IRQ response takes over at the vector
    ;; fetch.  The stack frame remains the hardware-interrupt frame above.
    (setf (cpu-irq-delay cpu) 0
          (cpu-pc cpu)
          (%read-vector-word
           bus (%interrupt-vector-address
                (%interrupt-vector-type type nmi-poll))))
    (incf (cpu-cycles cpu) 7)
    7))
