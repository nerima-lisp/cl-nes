(in-package #:cl-nes)

(defun %branch! (cpu bus condition)
  (let ((offset (%fetch-byte cpu bus)))
    (if condition
        (let* ((old-pc (cpu-pc cpu))
               (signed-offset (if (logbitp 7 offset)
                                  (- offset #x100)
                                  offset))
               (new-pc (logand (+ old-pc signed-offset) #xFFFF)))
          (bus-read bus old-pc)
          (when (/= (logand old-pc #xFF00)
                    (logand new-pc #xFF00))
            (bus-read bus
                      (logior (logand old-pc #xFF00)
                              (logand new-pc #x00FF))))
          (setf (cpu-pc cpu) new-pc)
          (let ((page-crossed-p
                  (/= (logand old-pc #xFF00)
                      (logand new-pc #xFF00))))
            (unless page-crossed-p
              (setf (cpu-irq-poll-delay cpu) t))
            (if page-crossed-p 4 3)))
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
  (setf (cpu-a cpu) 0
        (cpu-x cpu) 0
        (cpu-y cpu) 0
        (cpu-p cpu) #x24
        (cpu-sp cpu) #xFD
        (cpu-pc cpu) (logior (bus-read bus #xFFFC)
                            (ash (bus-read bus #xFFFD) 8))
        (cpu-cycles cpu) 0
        (cpu-irq-delay cpu) 0
        (cpu-irq-poll-delay cpu) nil
        (cpu-stopped-p cpu) nil)
  (incf (cpu-cycles cpu) 7)
  cpu)

(defun cpu-interrupt! (cpu bus type &optional force-p nmi-poll)
  (when (or (eq type :nmi)
            (and (eq type :irq)
                 (or force-p
                     (not (%flag-set-p cpu +flag-interrupt-disable+)))))
    ;; An interrupt response is a seven-cycle instruction.  The first two
    ;; cycles are discarded reads from the current PC; keeping them as bus
    ;; accesses matters for PPU/APU timing and mapper side effects.
    (bus-read bus (cpu-pc cpu))
    (bus-read bus (cpu-pc cpu))
    (%push-word! cpu bus (cpu-pc cpu))
    (%push-byte! cpu bus (%status-for-stack cpu nil))
    (%set-flag! cpu +flag-interrupt-disable+ t)
    (setf (cpu-irq-delay cpu) 0)
    ;; An NMI edge observed during an IRQ response takes over at the vector
    ;; fetch.  The stack frame remains the hardware-interrupt frame above.
    (let ((vector-type
            (if (and nmi-poll (funcall nmi-poll))
                :nmi
                type)))
      (setf (cpu-pc cpu)
            (if (eq vector-type :nmi)
                (logior (bus-read bus #xFFFA)
                        (ash (bus-read bus #xFFFB) 8))
                (logior (bus-read bus #xFFFE)
                        (ash (bus-read bus #xFFFF) 8)))))
    (incf (cpu-cycles cpu) 7)
    7))
