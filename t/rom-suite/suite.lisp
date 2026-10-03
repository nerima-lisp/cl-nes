(in-package #:cl-nes/rom-suite)

(defun result-summary (contract result)
  (format nil "~A passed=~A frames=~A text=~A status=~A error=~A"
          (rom-contract-id contract)
          (getf result :passed)
          (getf result :frames)
          (getf result :text)
          (getf result :status)
          (getf result :error)))

(defun run-contract (contract)
  (let ((path (resolve-rom-path contract)))
    (unless (probe-file path)
      (error "ROM input missing for ~A: ~A" (rom-contract-id contract) path))
    (handler-case
        (call-with-rom-test-timeout
         (rom-contract-id contract)
         (lambda ()
           (case (rom-contract-protocol contract)
             (:blargg (run-blargg-contract path contract))
             (:ram-result (run-ram-result-contract path contract))
             (:text-progress (run-text-progress-contract path contract))
             (:nametable-text (run-nametable-text-contract path contract))
             (:mmc1-a12 (run-mmc1-a12-contract path contract))
             (otherwise (error "Unknown ROM protocol ~S"
                               (rom-contract-protocol contract))))))
      (error (condition)
        (list :passed nil :error (princ-to-string condition)
              :text "condition signaled")))))

(defun enforce-ratchet (contract result)
  (let ((passed (getf result :passed)))
    (ecase (rom-contract-state contract)
      (:pass (unless passed
               (error "ratchet regression: ~A~%~A"
                      (rom-contract-id contract) (result-summary contract result))))
      (:known-fail (when passed
                     (error "ratchet update required: ~A unexpectedly passes~%~A"
                            (rom-contract-id contract)
                            (result-summary contract result))))))
  result)

(defun enforce-accuracy-ratchet (contract result)
  (let ((passed (getf result :passed))
        (pass-count (getf result :pass-count))
        (ratchet-count (getf contract :ratchet-pass-count))
        (ratchet-items (getf contract :ratchet-pass-items))
        (items (getf result :items)))
    (when (and ratchet-count (< pass-count ratchet-count))
      (error "accuracy ratchet regression: ~A pass count ~D < baseline ~D"
             (getf contract :id) pass-count ratchet-count))
    (dolist (name ratchet-items)
      (unless (some (lambda (item)
                      (and (string= name (getf item :name))
                           (eq :pass (getf item :kind))))
                    items)
        (error "accuracy ratchet regression: item lost: ~A" name)))
    (ecase (getf contract :state)
      (:pass (unless passed
               (error "ratchet regression: ~A~%pass=~D completed=~D expected=~D"
                      (getf contract :id)
                      (getf result :pass-count)
                      (getf result :completed-count)
                      (getf contract :expected))))
      (:known-fail (when passed
                     (error "ratchet update required: ~A unexpectedly passes~%pass=~D completed=~D"
                            (getf contract :id)
                            (getf result :pass-count)
                            (getf result :completed-count))))))
  result)

(defparameter *default-rom-worker-count* 1
  "Deterministic fallback when the runner does not select a worker count.")

(defparameter *default-rom-test-timeout-ms* 120000
  "Default wall-clock limit for one ROM protocol execution.")

(defun positive-environment-integer (name default)
  (let ((value (uiop:getenv name)))
    (if (null value)
        default
        (let ((parsed (ignore-errors (parse-integer value :junk-allowed nil))))
          (if (and parsed (plusp parsed))
              parsed
              (error "~A must be a positive integer: ~A" name value))))))

(defun rom-test-timeout-ms ()
  (positive-environment-integer "CL_NES_ROM_TEST_TIMEOUT_MS"
                                *default-rom-test-timeout-ms*))

(defun call-with-rom-test-timeout (label thunk)
  (let ((timeout-ms (rom-test-timeout-ms)))
    #+sbcl
    (handler-case
        (sb-ext:with-timeout (/ timeout-ms 1000.0d0)
          (funcall thunk))
      (sb-ext:timeout ()
        (error "ROM test unit ~A exceeded timeout-ms=~D"
               label timeout-ms)))
    #-sbcl
    (funcall thunk)))

(defun rom-worker-count ()
  (positive-environment-integer "CL_NES_ROM_WORKERS"
                                *default-rom-worker-count*))

(defun rom-suite-shard ()
  (let ((name (uiop:getenv "CL_NES_ROM_SUITE_SHARD")))
    (if (null name)
        :all
        (let ((shard (intern (string-upcase name) :keyword)))
          (if (member shard '(:cpu :ppu :apu-test :apu-dmc :apu-timing :dma :mapper))
              shard
              (error "Unknown ROM suite shard: ~A" name))))))

(defun rom-suite-contracts ()
  (let ((shard (rom-suite-shard)))
    (remove-if-not
     (lambda (contract)
       (or (eq shard :all)
           (and (eq shard :apu-test)
                (string= (rom-contract-id contract) "apu-test"))
           (and (eq shard :apu-dmc)
                (member (rom-contract-id contract)
                        '("apu-dmc-basics" "apu-dmc-rates")
                        :test #'string=))
           (and (eq shard :apu-timing)
                (let ((id (rom-contract-id contract)))
                  (and (>= (length id) 10)
                       (string= id "blargg-apu" :end1 10 :end2 10))))
           (eq (rom-contract-category contract) shard)))
     (rom-contract-table))))

(defun run-contracts-parallel (contracts)
  (let* ((count (length contracts))
         (worker-count (min count (rom-worker-count)))
         (results (make-array count))
         (next-index 0)
         (lock (sb-thread:make-mutex :name "rom-suite-work-queue"))
         (threads
           (loop repeat worker-count
                 collect
                 (sb-thread:make-thread
                  (lambda ()
                    (loop
                      (let ((index
                              (sb-thread:with-mutex (lock)
                                (when (< next-index count)
                                  (prog1 next-index
                                    (incf next-index))))))
                        (unless index (return))
                        (setf (aref results index)
                              (handler-case
                                  (run-contract (nth index contracts))
                                (error (condition)
                                  (list :passed nil
                                        :error (princ-to-string condition)
                                        :text "worker condition")))))))))))
    (dolist (thread threads)
      (sb-thread:join-thread thread))
    (loop for contract in contracts
          for index from 0
          collect (cons contract (aref results index)))))

(defun run-accuracy-contract ()
  (let ((path (accuracy-coin-path)))
    (unless (and path (probe-file path))
      (error "AccuracyCoin input missing: ~A" path))
    (call-with-rom-test-timeout
     "accuracy-coin"
     (lambda ()
       (let* ((contract *accuracy-coin-contract*)
              (result (run-accuracy-coin path contract))
              (pass-count (getf result :pass-count)))
         (enforce-accuracy-ratchet contract result)
         (format t "accuracy-coin pass=~D total=~D fail=~D skip=~D running=~D~%"
                 pass-count (getf result :total) (getf result :fail-count)
                 (getf result :skip-count) (getf result :running-count))
         (format t "accuracy-coin categories=~S~%"
                 (getf result :category-pass-counts))
         result)))))

(defun run-rom-suite ()
  (let ((results nil)
        (shard (rom-suite-shard))
        (contracts (rom-suite-contracts)))
    (format t "rom-suite shard=~A workers=~D contracts=~D~%"
            shard
            (min (length contracts) (rom-worker-count))
            (length contracts))
    (dolist (entry (run-contracts-parallel contracts))
      (let* ((contract (car entry))
             (result (enforce-ratchet contract (cdr entry))))
        (push result results)
        (unless (getf result :passed)
          (format *error-output* "ROM failed: ~A~%"
                  (result-summary contract result)))
        (format t "~A~%" (result-summary contract result))))
    (when (member shard '(:all :mapper))
      (run-accuracy-contract))
    (nreverse results)))

(defun run-rom-suite-table-tests ()
  (unless (uiop:symbol-call :cl-weave :run-all
                            :reporter :spec
                            :pass-with-no-tests nil)
    (error "ROM suite table tests failed."))
  t)

(defmacro define-rom-contract-tests ()
  `(progn
     (describe-each
      ,*rom-contract-test-data*
      "ROM contract ~A"
      (id category path protocol expected max-frames state failure-text mapper
       result-address running-value)
      (it "has a declarative protocol and bounded execution"
          (unless (and (stringp id) (keywordp category) (stringp path)
                       (or (numberp expected) (stringp expected))
                       (stringp failure-text)
                       (or (null mapper) (keywordp mapper))
                       (member protocol '(:blargg :ram-result :text-progress
                                          :nametable-text :mmc1-a12 :accuracy-coin))
                       (plusp max-frames)
                       (or (null result-address) (integerp result-address))
                       (or (null running-value) (integerp running-value))
                       (member state '(:pass :known-fail)))
            (error "invalid ROM contract"))))
     (cl-weave:describe "ROM suite table"
       (it-each
        ,*rom-contract-test-data*
        "table row ~A"
        (id category path protocol expected max-frames state failure-text mapper
         result-address running-value)
        (unless (and (stringp id) (stringp path))
          (error "invalid table row"))))))

(define-rom-contract-tests)

(defun rom-suite-main ()
  (handler-case
      (progn
        (run-rom-suite-table-tests)
        (run-rom-suite)
        (when (member (rom-suite-shard) '(:all :mapper))
          (let ((difference
                  (call-with-rom-test-timeout "nestest"
                                               #'run-nestest-trace)))
            (when difference
              (error "nestest required pass: ~A" difference))))
        0)
    (error (condition)
      (format *error-output* "ROM suite failed: ~A~%" condition)
      1)))
