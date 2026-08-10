(in-package #:cl-user)

(defparameter *project-root*
  (make-pathname :name nil
                 :type nil
                 :defaults (or *load-truename* *default-pathname-defaults*)))

(require :asdf)
(load (merge-pathnames "cl-nes.asd" *project-root*))
(asdf:test-system "cl-nes/test")
