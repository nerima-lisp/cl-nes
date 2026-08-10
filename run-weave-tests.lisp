(in-package #:cl-user)

(defparameter *weave-test-root*
  (make-pathname :name nil
                 :type nil
                 :defaults (or *load-truename*
                                *load-pathname*
                                *default-pathname-defaults*)))

(require :asdf)
(load (merge-pathnames "cl-nes.asd" *weave-test-root*))
(asdf:test-system "cl-nes/test")
