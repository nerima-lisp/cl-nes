(in-package #:cl-user)

(require :asdf)
(defparameter *project-root*
  (make-pathname :name nil :type nil
                 :defaults (or *load-truename* *default-pathname-defaults*)))

(load (merge-pathnames "cl-nes.asd" *project-root*))
(asdf:load-system "cl-nes/frontend/test")
(unless (uiop:symbol-call :cl-weave :run-all
                          :reporter :spec
                          :pass-with-no-tests nil)
  (error "cl-nes frontend test suite failed."))
