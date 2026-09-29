(in-package #:cl-nes/test)

(eval-when (:compile-toplevel :load-toplevel :execute)
  (defun %present-setf-pairs (specifications)
    (loop for (place value present-p) in specifications
          when present-p
          append (list place value))))

(defmacro with-fixture-apu
    ((apu &optional pulse pulse-2 triangle noise dmc) &body body)
  "Bind APU and optional channel aliases to a fresh fixture APU."
  `(let* ((,apu (make-apu))
          ,@(when pulse
              `((,pulse (cl-nes::apu-pulse-1 ,apu))))
          ,@(when pulse-2
              `((,pulse-2 (cl-nes::apu-pulse-2 ,apu))))
          ,@(when triangle
              `((,triangle (cl-nes::apu-triangle ,apu))))
          ,@(when noise
              `((,noise (cl-nes::apu-noise ,apu))))
          ,@(when dmc
              `((,dmc (cl-nes::apu-dmc ,apu)))))
     ,@body))

(defmacro write-apu-registers! (apu &body writes)
  "Write APU registers from ADDRESS/VALUE pairs."
  `(progn
     ,@(loop for (address value) in writes
             collect
             `(apu-write-register! ,apu ,address ,value))))
