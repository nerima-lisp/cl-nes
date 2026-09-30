(in-package #:cl-nes)

(defun %accumulator-rmw-op! (cpu operation)
  (setf (cpu-a cpu) (funcall operation cpu (cpu-a cpu)))
  2)

(defun %dummy-stack-read (cpu bus)
  (bus-read bus (+ #x100 (cpu-sp cpu))))

(defun %brk-op! (cpu bus nmi-poll)
  ;; BRK reads and discards its padding byte before pushing the
  ;; return address.
  (bus-read bus (cpu-pc cpu))
  (setf (cpu-pc cpu) (logand (1+ (cpu-pc cpu)) #xFFFF))
  (%push-word! cpu bus (cpu-pc cpu))
  (%push-byte! cpu bus (%status-for-stack cpu t))
  (%set-flag! cpu +flag-interrupt-disable+ t)
  ;; A pending NMI can hijack BRK after its stack writes but before
  ;; the interrupt vector is fetched. The pushed status still has BRK
  ;; set, as on the 6502.
  (let ((vector-type
          (if (and nmi-poll (funcall nmi-poll))
              :nmi
              :irq)))
    (setf (cpu-pc cpu)
          (if (eq vector-type :nmi)
              (logior (bus-read bus #xFFFA)
                      (ash (bus-read bus #xFFFB) 8))
              (logior (bus-read bus #xFFFE)
                      (ash (bus-read bus #xFFFF) 8)))))
  7)

(defun %php-op! (cpu bus)
  ;; PHP has an internal/dummy read before the stack write.
  (bus-read bus (cpu-pc cpu))
  (%push-byte! cpu bus (%status-for-stack cpu t))
  3)

(defun %jsr-op! (cpu bus)
  ;; JSR fetches the low target byte, performs a dummy stack read,
  ;; pushes the return address, and fetches the high target byte
  ;; last.
  (let* ((low (%fetch-byte cpu bus))
         (return-address (cpu-pc cpu)))
    (%dummy-stack-read cpu bus)
    (%push-byte! cpu bus (ldb (byte 8 8) return-address))
    (%push-byte! cpu bus (ldb (byte 8 0) return-address))
    (setf (cpu-pc cpu)
          (logior low (ash (%fetch-byte cpu bus) 8)))
    6))

(defun %plp-op! (cpu bus)
  ;; PLP has a dummy read from the next instruction byte and a second
  ;; dummy read from the current stack location.
  (bus-read bus (cpu-pc cpu))
  (%dummy-stack-read cpu bus)
  (%restore-status! cpu (%pop-byte! cpu bus))
  4)

(defun %rti-op! (cpu bus)
  ;; RTI's two cycles before pulling the status are dummy reads, one
  ;; from the next instruction and one from the current stack
  ;; location.
  (bus-read bus (cpu-pc cpu))
  (%dummy-stack-read cpu bus)
  (%restore-status! cpu (%pop-byte! cpu bus) nil)
  (setf (cpu-pc cpu) (%pop-word! cpu bus))
  6)

(defun %pha-op! (cpu bus)
  ;; PHA has an internal/dummy read before the stack write.
  (bus-read bus (cpu-pc cpu))
  (%push-byte! cpu bus (cpu-a cpu))
  3)

(defun %interrupt-disable-op! (cpu enabled-p)
  (let ((was-disabled (%flag-set-p cpu +flag-interrupt-disable+)))
    (%set-flag! cpu +flag-interrupt-disable+ enabled-p)
    (if enabled-p
        (unless was-disabled
          (setf (cpu-irq-delay cpu) 1))
        (when was-disabled
          (setf (cpu-irq-delay cpu) 1)))
    2))

(defun %rts-op! (cpu bus)
  ;; RTS performs a next-PC dummy read, a stack dummy read, pulls the
  ;; return address, then reads from the resumed PC.
  (bus-read bus (cpu-pc cpu))
  (%dummy-stack-read cpu bus)
  (setf (cpu-pc cpu)
        (logand (1+ (%pop-word! cpu bus)) #xFFFF))
  (bus-read bus (cpu-pc cpu))
  6)

(defun %pla-op! (cpu bus)
  ;; PLA has the same two dummy reads as PLP.
  (bus-read bus (cpu-pc cpu))
  (%dummy-stack-read cpu bus)
  (setf (cpu-a cpu) (%pop-byte! cpu bus))
  (%update-zn! cpu (cpu-a cpu))
  4)

(defun %jam-op! (cpu bus)
  (bus-read bus (cpu-pc cpu))
  (setf (cpu-stopped-p cpu) t)
  2)

(defun cpu-step! (cpu bus &optional nmi-poll)
  (declare (optimize (speed 3) (safety 1) (debug 1)))
  (if (cpu-stopped-p cpu)
      0
      (let ((opcode (%fetch-byte cpu bus)))
        (setf (cpu-irq-poll-delay cpu) nil)
        (let ((cycles (%dispatch-cpu-opcode cpu bus opcode nmi-poll)))
          (incf (cpu-cycles cpu) cycles)
          cycles))))
