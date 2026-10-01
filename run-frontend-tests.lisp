(in-package #:cl-user)

(require :asdf)
(defparameter *project-root*
  (make-pathname :name nil :type nil
                 :defaults (or *load-truename* *default-pathname-defaults*)))

(load (merge-pathnames "cl-nes.asd" *project-root*))
(asdf:load-system "cl-nes/frontend/test")
(let ((passed (uiop:symbol-call :cl-weave :run-all
                                :reporter :spec
                                :pass-with-no-tests nil)))
  (format t "frontend tests: passed=~A failed=~A~%"
          (if passed 1 0) (if passed 0 1))
  (unless passed
    (error "cl-nes frontend test suite failed.")))
