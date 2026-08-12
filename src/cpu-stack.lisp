(in-package #:cl-nes)

(defun %push-byte! (cpu bus value)
  (bus-write! bus (+ #x100 (cpu-sp cpu)) value)
  (setf (cpu-sp cpu) (logand (1- (cpu-sp cpu)) #xFF)))

(defun %pop-byte! (cpu bus)
  (setf (cpu-sp cpu) (logand (1+ (cpu-sp cpu)) #xFF))
  (bus-read bus (+ #x100 (cpu-sp cpu))))

(defun %push-word! (cpu bus value)
  (%push-byte! cpu bus (ldb (byte 8 8) value))
  (%push-byte! cpu bus (ldb (byte 8 0) value)))

(defun %pop-word! (cpu bus)
  (let ((low (%pop-byte! cpu bus))
        (high (%pop-byte! cpu bus)))
    (logior low (ash high 8))))

(defun %status-for-stack (cpu break-p)
  (logior (logand (cpu-p cpu) (lognot +flag-break+))
          +flag-unused+
          (if break-p +flag-break+ 0)))

(defun %restore-status! (cpu value &optional (delay-p t))
  (let ((was-disabled (%flag-set-p cpu +flag-interrupt-disable+))
        (new-status (logior (logand value (lognot +flag-break+))
                            +flag-unused+)))
    (setf (cpu-p cpu) new-status)
    (when (and delay-p
               (/= (if was-disabled 1 0)
                   (if (logbitp 2 new-status) 1 0)))
      (setf (cpu-irq-delay cpu) 1))))
