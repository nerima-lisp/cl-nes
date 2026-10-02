(in-package #:cl-user)

(require :asdf)

(defparameter *project-root*
  (make-pathname :name nil
                 :type nil
                 :defaults (or *load-truename* *default-pathname-defaults*)))

(defun run-tests-with-options ()
  (let ((options (uiop:symbol-call :cl-weave/cli
                                   :run-all-options-from-environment)))
    (unless (apply #'uiop:symbol-call
                   :cl-weave
                   :run-all
                   (append options (list :pass-with-no-tests nil)))
      (error "cl-nes cl-weave test suite failed."))))

(load (merge-pathnames "cl-nes.asd" *project-root*))
(asdf:load-system "cl-nes/test")
(run-tests-with-options)
