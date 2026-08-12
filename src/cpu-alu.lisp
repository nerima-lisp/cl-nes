(in-package #:cl-nes)

(define-cpu-alu-accumulator-ops)

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

(define-cpu-alu-compare-ops)

(defun %bit! (cpu value)
  (%set-flag! cpu +flag-zero+ (zerop (logand (cpu-a cpu) value)))
  (%set-flag! cpu +flag-overflow+ (logbitp 6 value))
  (%set-flag! cpu +flag-negative+ (logbitp 7 value)))

(define-cpu-alu-value-ops)

(define-cpu-alu-rmw-ops)

(define-cpu-alu-derived-ops)

(defun %unstable-store-op! (cpu bus index value)
  (let* ((base (%fetch-word cpu bus))
         (effective-address (logand (+ base index) #xFFFF))
         (effective-low (logand effective-address #xFF))
         (mask (logand (1+ (ldb (byte 8 8) effective-address)) #xFF))
         (stored (logand value mask))
         (address (logior effective-low (ash stored 8))))
    (bus-write! bus address stored)
    5))
