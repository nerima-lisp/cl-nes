(in-package #:cl-nes)

(defun %fetch-byte (cpu bus)
  (let ((value (bus-read bus (cpu-pc cpu))))
    (setf (cpu-pc cpu) (logand (1+ (cpu-pc cpu)) #xFFFF))
    value))

(defun %fetch-word (cpu bus)
  (let ((low (%fetch-byte cpu bus))
        (high (%fetch-byte cpu bus)))
    (logior low (ash high 8))))

(defun %read-word-zero-page (bus address)
  (let ((low (bus-read bus (logand address #xFF)))
        (high (bus-read bus (logand (1+ address) #xFF))))
    (logior low (ash high 8))))

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

(defun %address-for-mode (cpu bus mode)
  (ecase mode
    (:zp
     (values (%fetch-byte cpu bus) nil nil))
    (:zpx
     (let ((address (%fetch-byte cpu bus)))
       (bus-read bus address)
       (values (mod (+ address (cpu-x cpu)) 256) nil nil)))
    (:zpy
     (let ((address (%fetch-byte cpu bus)))
       (bus-read bus address)
       (values (mod (+ address (cpu-y cpu)) 256) nil nil)))
    (:abs
     (values (%fetch-word cpu bus) nil nil))
    (:absx
     (let* ((base (%fetch-word cpu bus))
            (address (logand (+ base (cpu-x cpu)) #xFFFF)))
       (values address
               (/= (logand base #xFF00) (logand address #xFF00))
               base)))
    (:absy
     (let* ((base (%fetch-word cpu bus))
            (address (logand (+ base (cpu-y cpu)) #xFFFF)))
       (values address
               (/= (logand base #xFF00) (logand address #xFF00))
               base)))
    (:indx
     (let* ((address (%fetch-byte cpu bus))
            (pointer (mod (+ address (cpu-x cpu)) 256)))
       (bus-read bus address)
       (values (%read-word-zero-page bus pointer) nil nil)))
    (:indy
     (let* ((pointer (%fetch-byte cpu bus))
            (base (%read-word-zero-page bus pointer))
            (address (logand (+ base (cpu-y cpu)) #xFFFF)))
       (values address
               (/= (logand base #xFF00) (logand address #xFF00))
               base)))))

(defun %read-op! (cpu bus mode operation page-cycle-p)
  (if (eq mode :immediate)
      (progn
        (funcall operation cpu (%fetch-byte cpu bus))
        2)
      (multiple-value-bind (address crossed-p base)
          (%address-for-mode cpu bus mode)
        (when (and page-cycle-p crossed-p)
          (bus-read bus
                    (logior (logand base #xFF00)
                            (logand address #x00FF))))
        (funcall operation cpu (bus-read bus address))
        (+ (ecase mode
             (:zp 3)
             (:zpx 4)
             (:zpy 4)
             (:abs 4)
             (:absx 4)
             (:absy 4)
             (:indx 6)
             (:indy 5))
           (if (and page-cycle-p crossed-p) 1 0)))))

(defun %nop-op! (cpu bus mode cycles)
  (if (eq mode :immediate)
      (progn
        (%fetch-byte cpu bus)
        cycles)
      (multiple-value-bind (address ignored-crossed-p)
          (%address-for-mode cpu bus mode)
        (declare (ignore ignored-crossed-p))
        (bus-read bus address)
        cycles)))

(defun %write-op! (cpu bus mode value)
  (multiple-value-bind (address ignored-crossed-p base)
      (%address-for-mode cpu bus mode)
    (declare (ignore ignored-crossed-p))
    (when (or (eq mode :absx)
              (eq mode :absy)
              (eq mode :indy))
      (bus-read bus
                (logior (logand base #xFF00)
                        (logand address #x00FF))))
    (bus-write! bus address value)
    (ecase mode
      (:zp 3)
      (:zpx 4)
      (:zpy 4)
      (:abs 4)
      (:absx 5)
      (:absy 5)
      (:indx 6)
      (:indy 6))))

(defun %rmw-op! (cpu bus mode operation cycles)
  (multiple-value-bind (address ignored-crossed-p base)
      (%address-for-mode cpu bus mode)
    (declare (ignore ignored-crossed-p))
    (when (or (eq mode :absx)
              (eq mode :absy)
              (eq mode :indy))
      (bus-read bus
                (logior (logand base #xFF00)
                        (logand address #x00FF))))
    (let* ((old-value (bus-read bus address))
           (new-value (funcall operation cpu old-value)))
      (bus-write! bus address old-value)
      (bus-write! bus address new-value))
    cycles))
