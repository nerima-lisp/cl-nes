(in-package #:cl-user)

(defparameter *project-root*
  (make-pathname :name nil
                 :type nil
                 :defaults (or *load-truename* *default-pathname-defaults*)))

(require :asdf)
(load (merge-pathnames "cl-nes.asd" *project-root*))
(asdf:load-system "cl-nes/test")

(multiple-value-bind (passed failed)
    (uiop:symbol-call :cl-nes/test-runner :run-legacy-tests)
  (let ((total (+ passed failed)))
    (format t "~%Assertions: ~D passed, ~D failed~%" passed failed)
    (cond
      ((zerop total)
       (format *error-output* "No assertions were selected.~%")
       (uiop:quit 1))
      ((zerop failed)
       (uiop:quit 0))
      (t
       (uiop:quit 1)))))
