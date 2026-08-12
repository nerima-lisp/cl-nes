(in-package #:cl-nes)

(defmacro %set-cpu-state-slot! (cpu accessor value)
  `(ecase ,accessor
     ,@(loop for (slot) in +cpu-reset-state-specs+
             collect `(,slot (setf (,slot ,cpu) ,value)))))
