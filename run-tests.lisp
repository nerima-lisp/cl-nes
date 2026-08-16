(in-package #:cl-user)

(require :asdf)

(defparameter *project-root*
  (make-pathname :name nil
                 :type nil
                 :defaults (or *load-truename* *default-pathname-defaults*)))

(defun getenv-non-empty (name)
  (let ((value (uiop:getenv name)))
    (and value
         (not (string= value ""))
         value)))

(defun parse-integer-env (name)
  (let ((value (getenv-non-empty name)))
    (when value
      (parse-integer value))))

(defun split-string-on-substring (string separator)
  (let ((parts '())
        (start 0))
    (loop
      for position = (search separator string :start2 start)
      do (if position
             (progn
               (push (subseq string start position) parts)
               (setf start (+ position (length separator))))
             (return)))
    (push (subseq string start) parts)
    (nreverse parts)))

(defun parse-comma-list-env (name)
  (let ((value (getenv-non-empty name)))
    (when value
      (loop for item in (split-string-on-substring value ",")
            for trimmed = (string-trim '(#\Space #\Tab #\Newline) item)
            unless (string= trimmed "")
              collect trimmed))))

(defun parse-reporter-env (name)
  (let ((value (getenv-non-empty name)))
    (when value
      (intern (string-upcase value) :keyword))))

(defun parse-test-path-filter-env (name)
  (let ((value (getenv-non-empty name)))
    (when value
      (loop for item in (split-string-on-substring value ",")
            for trimmed = (string-trim '(#\Space #\Tab #\Newline) item)
            unless (string= trimmed "")
              collect
              (loop for component in (split-string-on-substring trimmed " > ")
                    for normalized = (string-trim '(#\Space #\Tab #\Newline) component)
                    unless (string= normalized "")
                      collect normalized)))))

(defun run-tests-with-options ()
  (let ((reporter (or (parse-reporter-env "CL_NES_TEST_REPORTER") :spec))
        (name-filter (getenv-non-empty "CL_NES_TEST_NAME_FILTER"))
        (location-filter (parse-comma-list-env "CL_NES_TEST_LOCATION_FILTER"))
        (test-path-filter (parse-test-path-filter-env "CL_NES_TEST_PATH_FILTER"))
        (include-tags (parse-comma-list-env "CL_NES_TEST_INCLUDE_TAGS"))
        (exclude-tags (parse-comma-list-env "CL_NES_TEST_EXCLUDE_TAGS"))
        (seed (parse-integer-env "CL_NES_TEST_SEED"))
        (timeout-ms (parse-integer-env "CL_NES_TEST_TIMEOUT_MS"))
        (max-workers (parse-integer-env "CL_NES_TEST_MAX_WORKERS")))
    (unless (uiop:symbol-call :cl-weave :run-all
                              :reporter reporter
                              :name-filter name-filter
                              :location-filter location-filter
                              :test-path-filter test-path-filter
                              :include-tags include-tags
                              :exclude-tags exclude-tags
                              :seed seed
                              :timeout-ms timeout-ms
                              :max-workers max-workers
                              :pass-with-no-tests nil)
      (error "cl-nes cl-weave test suite failed."))))

(load (merge-pathnames "cl-nes.asd" *project-root*))
(asdf:load-system "cl-nes/test")
(run-tests-with-options)
