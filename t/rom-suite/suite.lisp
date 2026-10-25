(in-package #:cl-nes/rom-suite)

(defun result-summary (contract result)
  (format nil "~A passed=~A frames=~A text=~A status=~A error=~A"
          (rom-contract-id contract)
          (getf result :passed)
          (getf result :frames)
          (getf result :text)
          (getf result :status)
          (getf result :error)))

(defparameter *rom-test-timeout-ms-per-frame* 73
  "Maximum observed wall-clock milliseconds per completed NES frame, rounded up.")

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
  "Bounded fallback for protocols without a frame limit.")
(defun run-contract (contract)
  (let ((path (resolve-rom-path contract))
        (*rom-test-timeout-ms-per-frame*
          (or (rom-contract-timeout-ms-per-frame contract)
              *rom-test-timeout-ms-per-frame*)))
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
                               (rom-contract-protocol contract)))))
         (rom-contract-max-frames contract))
      (error (condition)
        (list :passed nil :error (princ-to-string condition)
              :text "condition signaled")))))
(defparameter *rom-test-timeout-margin* 2.0d0
  "Multiplier applied to the measured wall-clock cost per frame.")
(defparameter *rom-test-timeout-startup-ms* 1000
  "Allowance for runner startup before frame execution.")

(defun positive-integer-value (name value)
  (let ((parsed (ignore-errors (parse-integer value :junk-allowed nil))))
    (if (and parsed (plusp parsed))
        parsed
        (error "~A must be a positive integer: ~A" name value))))

(defun positive-environment-integer (name default)
  (let ((value (uiop:getenv name)))
    (if (null value)
        default
        (positive-integer-value name value))))

(defun rom-test-timeout-ms (&optional max-frames
                            (override (uiop:getenv "CL_NES_ROM_TEST_TIMEOUT_MS")))
  (if override
      (positive-integer-value "CL_NES_ROM_TEST_TIMEOUT_MS" override)
      (if max-frames
          (rom-test-timeout-for-frames max-frames)
          *default-rom-test-timeout-ms*)))

(defun rom-test-timeout-for-frames (max-frames)
  (unless (and (integerp max-frames) (plusp max-frames))
    (error "ROM max-frames must be a positive integer: ~S" max-frames))
  (unless (and (realp *rom-test-timeout-ms-per-frame*)
               (plusp *rom-test-timeout-ms-per-frame*)
               (realp *rom-test-timeout-margin*)
               (>= *rom-test-timeout-margin* 1)
               (integerp *rom-test-timeout-startup-ms*)
               (not (minusp *rom-test-timeout-startup-ms*)))
    (error "Invalid ROM test timeout calibration"))
  (+ *rom-test-timeout-startup-ms*
     (ceiling (* max-frames
                 *rom-test-timeout-ms-per-frame*
                 *rom-test-timeout-margin*))))

(defun call-with-rom-test-timeout (label thunk &optional max-frames)
  (let ((timeout-ms (rom-test-timeout-ms max-frames)))
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
  (let* ((contract *accuracy-coin-contract*)
         (path (accuracy-coin-path))
         (*rom-test-timeout-ms-per-frame*
           (or (getf contract :timeout-ms-per-frame)
               *rom-test-timeout-ms-per-frame*)))
    (unless (and path (probe-file path))
      (error "AccuracyCoin input missing: ~A" path))
    (call-with-rom-test-timeout
     "accuracy-coin"
     (lambda ()
       (let ((result (run-accuracy-coin path contract)))
         (format t
                 "accuracy-coin frames=~D complete=~A completed=~D total=~D reserved=~D pass=~D fail=~D skip=~D running=~D~%"
                 (getf result :frames) (getf result :completed-p)
                 (getf result :completed-count) (getf result :total)
                 (getf result :reserved-count) (getf result :pass-count)
                 (getf result :fail-count) (getf result :skip-count)
                 (getf result :running-count))
         (format t "accuracy-coin categories=~S~%"
                 (getf result :category-pass-counts))
         (dolist (item (getf result :items))
           (format t "accuracy-coin item ~A address=$~4,'0X value=$~2,'0X kind=~A~%"
                   (getf item :name) (getf item :address)
                   (getf item :value) (getf item :kind)))
         (dolist (item (getf result :shared-draw-items))
           (format t "accuracy-coin shared-item ~A value=$~2,'0X kind=~A~%"
                   (getf item :name) (getf item :value) (getf item :kind)))
         (when (getf result :unfinished-items)
           (error "AccuracyCoin unfinished expected-pass items: ~{~A~^, ~}"
                  (getf result :unfinished-items)))
         (unless (getf result :completed-p)
           (error "AccuracyCoin automatic run reached max-frames=~D before completion"
                  (getf contract :max-frames)))
         (enforce-accuracy-ratchet contract result)
         result))
     (getf contract :max-frames))))

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
       result-address running-value timeout-ms-per-frame)
      (it "has a declarative protocol and bounded execution"
          (unless (and (stringp id) (keywordp category) (stringp path)
                       (or (numberp expected) (stringp expected))
                       (stringp failure-text)
                       (or (null mapper) (keywordp mapper))
                       (member protocol '(:blargg :ram-result :text-progress
                                          :nametable-text :mmc1-a12 :accuracy-coin))
                       (plusp max-frames)
                       (or (null result-address) (integerp result-address))
                       (and (or (null running-value) (integerp running-value))
                            (or (null timeout-ms-per-frame)
                                (and (integerp timeout-ms-per-frame)
                                     (plusp timeout-ms-per-frame))))
                       (member state '(:pass :known-fail)))
            (error "invalid ROM contract"))))
     (cl-weave:describe "ROM suite table"
       (it-each
        ,*rom-contract-test-data*
        "table row ~A"
        (id category path protocol expected max-frames state failure-text mapper
         result-address running-value timeout-ms-per-frame)
        (unless (and (stringp id) (stringp path)
                     (or (null timeout-ms-per-frame)
                         (and (integerp timeout-ms-per-frame)
                              (plusp timeout-ms-per-frame))))
          (error "invalid table row")))
       (it "classifies AccuracyCoin result values"
         (cl-weave:expect (accuracy-result-kind #xff) :to-be :skipped)
         (cl-weave:expect (accuracy-result-kind #x01) :to-be :pass)
         (cl-weave:expect (accuracy-result-kind 3) :to-be :running))
       (it "names unfinished AccuracyCoin items"
         (cl-weave:expect
          (accuracy-coin-unfinished-items
           (list (list :name "unrun" :expected :pass :value 0)
                 (list :name "running" :expected :pass :value 3)
                 (list :name "skipped" :expected :pass :value #xff)
                 (list :name "failed" :expected :pass :value 2)
                 (list :name "reserved" :expected :reserved :value 0)))
          :to-equal '("unrun" "running" "skipped")))
       (it "waits for all AccuracyCoin results before completion"
         (let ((ram (make-array #x496 :initial-element 0))
               (addresses (list #x0400 #x0495)))
           (setf (aref ram #x35) 0
                 (aref ram #x0400) 1
                 (aref ram #x0495) 0)
           (cl-weave:expect
            (cl-nes::protocol-accuracy-coin-complete-p ram t addresses)
            :to-be nil)
           (setf (aref ram #x0495) 3)
           (cl-weave:expect
            (cl-nes::protocol-accuracy-coin-complete-p ram t addresses)
            :to-be nil)
           (setf (aref ram #x0495) #xff)
           (cl-weave:expect
            (cl-nes::protocol-accuracy-coin-complete-p ram t addresses)
            :to-be nil)
           (setf (aref ram #x0495) #x06)
           (cl-weave:expect
            (cl-nes::protocol-accuracy-coin-complete-p ram t addresses)
            :to-be t)
           (setf (aref ram #x35) 1)
           (cl-weave:expect
            (cl-nes::protocol-accuracy-coin-complete-p ram t addresses)
            :to-be nil)
           (setf (aref ram #x35) 0)
           (cl-weave:expect
            (cl-nes::protocol-accuracy-coin-complete-p ram nil addresses)
            :to-be nil)))
       (it "derives the timeout from frames with a startup allowance"
         (let ((*rom-test-timeout-ms-per-frame* 3)
               (*rom-test-timeout-margin* 1.25d0)
               (*rom-test-timeout-startup-ms* 7))
           (cl-weave:expect (rom-test-timeout-ms 10 nil)
                            :to-equal 45)
           (cl-weave:expect
            (let* ((contract
                     (find-if (lambda (row)
                                (string= (rom-contract-id row) "blargg-ppu-palette-ram"))
                              (rom-contract-table)))
                   (rate (rom-contract-timeout-ms-per-frame contract))
                   (timeout
                     (let ((*rom-test-timeout-ms-per-frame* (or rate 3))
                           (*rom-test-timeout-margin* 1.5d0)
                           (*rom-test-timeout-startup-ms* 1000))
                       (rom-test-timeout-ms (rom-contract-max-frames contract) nil))))
              (list (rom-test-timeout-ms 100 nil) rate timeout))
            :to-equal (list 382 208 113320))))
       (it "keeps the global override and no-frame fallback"
         (cl-weave:expect (rom-test-timeout-ms nil nil)
                          :to-equal *default-rom-test-timeout-ms*)
         (cl-weave:expect (rom-test-timeout-ms 10 "2500")
                          :to-equal 2500))
       (it "rejects invalid frame limits and timeout settings"
         (dolist (max-frames '(0 -1 1.5 "10" nil))
           (cl-weave:expect
            (handler-case
                (progn (rom-test-timeout-for-frames max-frames) nil)
              (error () t))
            :to-be t))
         (cl-weave:expect
          (handler-case (progn (rom-test-timeout-ms 10 "0") nil)
            (error () t))
          :to-be t)
         (let ((*rom-test-timeout-ms-per-frame* 0))
           (cl-weave:expect
            (handler-case (progn (rom-test-timeout-for-frames 10) nil)
              (error () t))
            :to-be t))
         (let ((*rom-test-timeout-margin* 0.5d0))
           (cl-weave:expect
            (handler-case (progn (rom-test-timeout-for-frames 10) nil)
              (error () t))
            :to-be t)))
       (it "uses each contract frame limit and calibrated timeout rate"
         (let ((*rom-test-timeout-ms-per-frame* 2)
               (*rom-test-timeout-margin* 1d0)
               (*rom-test-timeout-startup-ms* 5))
           (let ((contract (first (rom-contract-table))))
             (cl-weave:expect
              (rom-test-timeout-ms (rom-contract-max-frames contract) nil)
              :to-equal (+ 5 (* 2 (rom-contract-max-frames contract)))))
           (cl-weave:expect
            (rom-test-timeout-ms
             (getf *accuracy-coin-contract* :max-frames) nil)
            :to-equal
            (+ 5 (* 2 (getf *accuracy-coin-contract* :max-frames)))))
         (let ((*rom-test-timeout-ms-per-frame*
                 (getf *accuracy-coin-contract* :timeout-ms-per-frame))
               (*rom-test-timeout-margin* 2.0d0)
               (*rom-test-timeout-startup-ms* 1000))
           (cl-weave:expect
            (rom-test-timeout-ms
             (getf *accuracy-coin-contract* :max-frames) nil)
            :to-equal 451248))
         (let ((*rom-test-timeout-margin* 2.0d0)
               (*rom-test-timeout-startup-ms* 1000))
           (cl-weave:expect
            (sort
             (loop for contract in (rom-contract-table)
                   for rate = (rom-contract-timeout-ms-per-frame contract)
                   when rate
                     collect
                       (list (rom-contract-id contract)
                             (let ((*rom-test-timeout-ms-per-frame* rate))
                               (rom-test-timeout-ms
                                (rom-contract-max-frames contract) nil))))
             (function string<) :key (function first))
            :to-equal
            (quote (("blargg-ppu-palette-ram" 150760)
                    ("cpu-exec-space-apu" 103900)
                    ("cpu-interrupts-v2-04-irq-dma" 31240)
                    ("cpu-interrupts-v2-05-branch" 22360)
                    ("cpu-reset-registers" 105000)))))))))

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
