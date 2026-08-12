(in-package #:cl-nes)

(defmacro define-cpu-register-loaders ()
  `(progn
     ,@(loop for (name accessor)
               in '((%load-a! cpu-a)
                    (%load-x! cpu-x)
                    (%load-y! cpu-y))
             collect
             `(defun ,name (cpu value)
                (%update-zn! cpu (setf (,accessor cpu) value))))))
