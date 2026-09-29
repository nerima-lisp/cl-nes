(in-package #:cl-nes)

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

(defun %xaa! (cpu value)
  (let ((result (logand (cpu-x cpu) value #xEE)))
    (%update-zn! cpu (setf (cpu-a cpu) result))))

(defun %las! (cpu value)
  (let ((result (logand value (cpu-sp cpu))))
    (setf (cpu-a cpu) result
          (cpu-x cpu) result
          (cpu-sp cpu) result)
    (%update-zn! cpu result)))

(defun %tas-op! (cpu bus)
  (let* ((base (%fetch-word cpu bus))
         (address (logand (+ base (cpu-y cpu)) #xFFFF))
         (mask (logand (1+ (ldb (byte 8 8) address)) #xFF))
         (stored (logand (setf (cpu-sp cpu) (logand (cpu-a cpu) (cpu-x cpu)))
                         mask)))
    (bus-write! bus (logior (logand address #xFF) (ash stored 8)) stored)
    5))

(defun %sha-mode-op! (cpu bus mode cycles)
  (multiple-value-bind (address crossed-p base)
      (%address-for-mode cpu bus mode)
    (when (and (eq mode :indy) crossed-p)
      (bus-read bus (logior (logand base #xFF00)
                            (logand address #x00FF))))
    (let* ((mask (logand (1+ (ldb (byte 8 8) address)) #xFF))
           (stored (logand (cpu-a cpu) (cpu-x cpu) mask)))
      (bus-write! bus (logior (logand address #xFF) (ash stored 8)) stored)
      cycles)))

(defun %unstable-store-op! (cpu bus index value)
  (let* ((base (%fetch-word cpu bus))
         (effective-address (logand (+ base index) #xFFFF))
         (effective-low (logand effective-address #xFF))
         (mask (logand (1+ (ldb (byte 8 8) effective-address)) #xFF))
         (stored (logand value mask))
         (address (logior effective-low (ash stored 8))))
    (bus-write! bus address stored)
    5))
