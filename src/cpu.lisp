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
