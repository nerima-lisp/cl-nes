(in-package #:cl-nes)

(defun make-cpu ()
  (%make-cpu))

(defun %flag-set-p (cpu flag)
  (not (zerop (logand (cpu-p cpu) flag))))

(defun %set-flag! (cpu flag enabled-p)
  (setf (cpu-p cpu)
        (if enabled-p
            (logior (cpu-p cpu) flag)
            (logand (cpu-p cpu) (lognot flag))))
  (setf (cpu-p cpu) (logior (cpu-p cpu) +flag-unused+)))

(defun %update-zn! (cpu value)
  (setf value (logand value #xFF))
  (%set-flag! cpu +flag-zero+ (zerop value))
  (%set-flag! cpu +flag-negative+ (not (zerop (logand value #x80))))
  value)

(defun %load-a! (cpu value)
  (%update-zn! cpu (setf (cpu-a cpu) value)))

(defun %load-x! (cpu value)
  (%update-zn! cpu (setf (cpu-x cpu) value)))

(defun %load-y! (cpu value)
  (%update-zn! cpu (setf (cpu-y cpu) value)))

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
     (values (mod (+ (%fetch-byte cpu bus) (cpu-x cpu)) 256) nil nil))
    (:zpy
     (values (mod (+ (%fetch-byte cpu bus) (cpu-y cpu)) 256) nil nil))
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
     (let ((pointer (mod (+ (%fetch-byte cpu bus) (cpu-x cpu)) 256)))
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

(defun %ora! (cpu value)
  (%update-zn! cpu (setf (cpu-a cpu) (logior (cpu-a cpu) value))))

(defun %and! (cpu value)
  (%update-zn! cpu (setf (cpu-a cpu) (logand (cpu-a cpu) value))))

(defun %eor! (cpu value)
  (%update-zn! cpu (setf (cpu-a cpu) (logxor (cpu-a cpu) value))))

(defun %adc! (cpu value)
  (let* ((a (cpu-a cpu))
         (carry (if (%flag-set-p cpu +flag-carry+) 1 0))
         (sum (+ a value carry))
         (result (logand sum #xFF)))
    (%set-flag! cpu +flag-carry+ (> sum #xFF))
    (%set-flag! cpu +flag-overflow+
                (not (zerop (logand (lognot (logxor a value))
                                    (logxor a result)
                                    #x80))))
    (%update-zn! cpu (setf (cpu-a cpu) result))))

(defun %sbc! (cpu value)
  (%adc! cpu (logxor value #xFF)))

(defun %compare! (cpu register value)
  (let ((difference (logand (- register value) #xFF)))
    (%set-flag! cpu +flag-carry+ (>= register value))
    (%update-zn! cpu difference)))

(defun %cmp-a! (cpu value)
  (%compare! cpu (cpu-a cpu) value))

(defun %cmp-x! (cpu value)
  (%compare! cpu (cpu-x cpu) value))

(defun %cmp-y! (cpu value)
  (%compare! cpu (cpu-y cpu) value))

(defun %bit! (cpu value)
  (%set-flag! cpu +flag-zero+ (zerop (logand (cpu-a cpu) value)))
  (%set-flag! cpu +flag-overflow+ (not (zerop (logand value #x40))))
  (%set-flag! cpu +flag-negative+ (not (zerop (logand value #x80)))))

(defun %asl-value! (cpu value)
  (%set-flag! cpu +flag-carry+ (not (zerop (logand value #x80))))
  (%update-zn! cpu (logand (ash value 1) #xFF)))

(defun %lsr-value! (cpu value)
  (%set-flag! cpu +flag-carry+ (not (zerop (logand value 1))))
  (%update-zn! cpu (ash value -1)))

(defun %rol-value! (cpu value)
  (let ((carry-in (if (%flag-set-p cpu +flag-carry+) 1 0)))
    (%set-flag! cpu +flag-carry+ (not (zerop (logand value #x80))))
    (%update-zn! cpu (logand (logior (ash value 1) carry-in) #xFF))))

(defun %ror-value! (cpu value)
  (let ((carry-in (if (%flag-set-p cpu +flag-carry+) #x80 0)))
    (%set-flag! cpu +flag-carry+ (not (zerop (logand value 1))))
    (%update-zn! cpu (logior (ash value -1) carry-in))))

(defun %inc-value! (cpu value)
  (%update-zn! cpu (mod (1+ value) 256)))

(defun %dec-value! (cpu value)
  (%update-zn! cpu (mod (1- value) 256)))

(defun %slo-value! (cpu value)
  (let ((shifted (%asl-value! cpu value)))
    (%ora! cpu shifted)
    shifted))

(defun %rla-value! (cpu value)
  (let ((rotated (%rol-value! cpu value)))
    (%and! cpu rotated)
    rotated))

(defun %sre-value! (cpu value)
  (let ((shifted (%lsr-value! cpu value)))
    (%eor! cpu shifted)
    shifted))

(defun %rra-value! (cpu value)
  (let ((rotated (%ror-value! cpu value)))
    (%adc! cpu rotated)
    rotated))

(defun %dcp-value! (cpu value)
  (let ((decremented (%dec-value! cpu value)))
    (%cmp-a! cpu decremented)
    decremented))

(defun %isc-value! (cpu value)
  (let ((incremented (%inc-value! cpu value)))
    (%sbc! cpu incremented)
    incremented))

(defun %lax! (cpu value)
  (setf (cpu-a cpu) value
        (cpu-x cpu) value)
  (%update-zn! cpu value))

(defun %aac! (cpu value)
  (let ((result (%and! cpu value)))
    (%set-flag! cpu +flag-carry+ (not (zerop (logand result #x80))))
    result))

(defun %asr! (cpu value)
  (let ((result (%lsr-value! cpu (%and! cpu value))))
    (setf (cpu-a cpu) result)
    result))

(defun %arr! (cpu value)
  (let* ((masked (logand (cpu-a cpu) value))
         (carry-in (if (%flag-set-p cpu +flag-carry+) #x80 0))
         (result (logand (logior (ash masked -1) carry-in) #xFF)))
    (setf (cpu-a cpu) result)
    (%update-zn! cpu result)
    (%set-flag! cpu +flag-carry+ (not (zerop (logand result #x40))))
    (%set-flag! cpu +flag-overflow+
                (not (eql (logbitp 6 result)
                          (logbitp 5 result))))
    result))

(defun %atx! (cpu value)
  (setf (cpu-a cpu) (logand (logior (cpu-a cpu) #xFF) value)
        (cpu-x cpu) (cpu-a cpu))
  (%update-zn! cpu (cpu-a cpu)))

(defun %axs! (cpu value)
  (let* ((masked (logand (cpu-a cpu) (cpu-x cpu)))
         (result (logand (- masked value) #xFF)))
    (setf (cpu-x cpu) result)
    (%set-flag! cpu +flag-carry+ (>= masked value))
    (%update-zn! cpu result)))

(defun %unstable-store-op! (cpu bus index value)
  (let* ((base (%fetch-word cpu bus))
         (effective-address (logand (+ base index) #xFFFF))
         (effective-low (logand effective-address #xFF))
         (mask (logand (1+ (ldb (byte 8 8) effective-address)) #xFF))
         (stored (logand value mask))
         (address (logior effective-low (ash stored 8))))
    (bus-write! bus address stored)
    5))

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
          (if (= (logand old-pc #xFF00) (logand new-pc #xFF00)) 3 4))
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
        (cpu-stopped-p cpu) nil)
  (incf (cpu-cycles cpu) 7)
  cpu)

(defun cpu-interrupt! (cpu bus type &optional force-p)
  (when (or (eq type :nmi)
            (and (eq type :irq)
                 (or force-p
                     (not (%flag-set-p cpu +flag-interrupt-disable+)))))
    (%push-word! cpu bus (cpu-pc cpu))
    (%push-byte! cpu bus (%status-for-stack cpu nil))
    (%set-flag! cpu +flag-interrupt-disable+ t)
    (setf (cpu-irq-delay cpu) 0)
    (setf (cpu-pc cpu)
          (if (eq type :nmi)
              (logior (bus-read bus #xFFFA)
                      (ash (bus-read bus #xFFFB) 8))
              (logior (bus-read bus #xFFFE)
                      (ash (bus-read bus #xFFFF) 8))))
    (incf (cpu-cycles cpu) 7)
    7))
