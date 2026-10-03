(in-package #:cl-user)

(require :asdf)

(defparameter *project-root*
  (make-pathname :name nil
                 :type nil
                 :defaults (or *load-truename* *default-pathname-defaults*)))

(load (merge-pathnames "cl-nes.asd" *project-root*))
(asdf:load-system "cl-nes/test")

(unless
    (uiop:symbol-call :cl-weave
                      :run-all
                      :reporter :spec
                      :include-tags '("heavy")
                      :timeout-ms 300000
                      :max-workers 1
                      :pass-with-no-tests nil)
  (error "cl-nes heavy test tier failed."))
