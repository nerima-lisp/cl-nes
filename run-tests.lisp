(in-package #:cl-user)

(require :asdf)

(defparameter *project-root*
  (make-pathname :name nil
                 :type nil
                 :defaults (or *load-truename* *default-pathname-defaults*)))

(defparameter *default-test-timeout-ms* 30000
  "Default timeout for one cl-weave test when the runner did not set one.")

(defun test-timeout-from-environment ()
  (let ((value (uiop:getenv "CL_NES_TEST_TIMEOUT_MS")))
    (and value
         (let ((parsed (ignore-errors
                         (parse-integer value :junk-allowed nil))))
           (unless (and parsed (plusp parsed))
             (error "CL_NES_TEST_TIMEOUT_MS must be a positive integer: ~A"
                    value))
           parsed))))

(defun run-tests-with-options ()
  (let ((options (uiop:symbol-call :cl-weave/cli
                                   :run-all-options-from-environment)))
    (unless (getf options :timeout-ms)
      (setf (getf options :timeout-ms)
            (or (test-timeout-from-environment)
                *default-test-timeout-ms*)))
    (format t "cl-weave test timeout-ms=~D~%"
            (getf options :timeout-ms))
    (unless (apply #'uiop:symbol-call
                   :cl-weave
                   :run-all
                   (append options (list :pass-with-no-tests nil)))
      (error "cl-nes cl-weave test suite failed."))))

(load (merge-pathnames "cl-nes.asd" *project-root*))
(asdf:load-system "cl-nes/test")
(run-tests-with-options)
