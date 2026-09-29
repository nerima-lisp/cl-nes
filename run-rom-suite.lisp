(in-package #:cl-user)

(defparameter *run-rom-suite-root*
  (make-pathname :name nil :type nil
                 :defaults (or *load-truename* *load-pathname*
                               *default-pathname-defaults*)))

(require :asdf)
(load (merge-pathnames "cl-nes.asd" *run-rom-suite-root*))
(asdf:load-system "cl-nes/rom-suite")
(sb-ext:exit :code (cl-nes/rom-suite:rom-suite-main))
