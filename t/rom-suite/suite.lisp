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
  "Per-frame thread CPU budget capped using observed wall time.")

(defun enforce-ratchet (contract result)
  (let ((passed (getf result :passed)))
    (ecase (rom-contract-state contract)
      (:pass (unless passed
               (error "ratchet regression: ~A~%~A"
                      (rom-contract-id contract) (result-summary contract result))))
      (:known-fail
       (cond
         (passed
          (error "ratchet update required: ~A unexpectedly passes~%~A"
                 (rom-contract-id contract)
                 (result-summary contract result)))
         ((getf result :error)
          (error "ratchet regression: ~A known-fail contract errored~%~A"
                 (rom-contract-id contract)
                 (result-summary contract result)))
         (t
          (let* ((expected (rom-contract-failure-text contract))
                 (status (getf result :status))
                 (text (or (getf result :text) ""))
                 (observed
                   (cond
                     ((and (numberp status)
                           (eq :blargg (rom-contract-protocol contract))
                           (not (getf result :signature)))
                      (format nil "status ~D but signature mismatch" status))
                     ((and (numberp status)
                           (eq :blargg (rom-contract-protocol contract))
                           (>= (or (getf result :frames) 0)
                               (rom-contract-max-frames contract))
                           (not (search "FAILED" (string-upcase text))))
                      (format nil "status ~D; incomplete at text ~A"
                              status text))
                     ((numberp status)
                      (format nil "status ~D; ~A" status text))
                     (t (result-summary contract result)))))
            (unless (search expected observed :test (function char-equal))
              (error "ratchet regression: ~A failure-text mismatch~%expected: ~A~%observed: ~A"
                     (rom-contract-id contract) expected observed))))))))
  result)

(defun enforce-accuracy-ratchet (contract result)
  (let* ((passed (getf result :passed))
         (pass-count (getf result :pass-count))
         (ratchet-count (getf contract :ratchet-pass-count))
         (ratchet-items (getf contract :ratchet-pass-items))
         (items (getf result :items))
         (lost-items
           (loop for name in ratchet-items
                 unless (some (lambda (item)
                                (and (string= name (getf item :name))
                                     (eq :pass (getf item :kind))))
                              items)
                   collect name))
         (failures nil))
    (when (and ratchet-count (< pass-count ratchet-count))
      (push (format nil "pass count ~D < baseline ~D"
                    pass-count ratchet-count)
            failures))
    (dolist (name lost-items)
      (push (format nil "item lost: ~A" name) failures))
    (when failures
      (error "accuracy ratchet regression: ~A~%~{~A~%~}"
             (getf contract :id)
             (nreverse failures)))
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
                            (getf result :completed-count)))))
    result))

(defparameter *default-rom-worker-count* 1
  "Deterministic fallback when the runner does not select a worker count.")

(defparameter *default-rom-test-timeout-ms* 120000
  "Bounded per-thread CPU fallback when no frame limit is available.")
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
  "Safety factor for each contract per-thread CPU budget.")
(defparameter *rom-test-timeout-startup-ms* 1000
  "Per-test setup allowance in the thread CPU budget.")

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

(progn
  (defun rom-test-cpu-timeout-ms
      (max-frames
       &optional (override (uiop:getenv "CL_NES_ROM_TEST_TIMEOUT_MS")))
    (rom-test-timeout-ms max-frames override))
  #+darwin
  (progn
    (defconstant +rom-suite-thread-basic-info+ 3)
    (sb-alien:define-alien-routine
        ("thread_info" rom-suite-mach-thread-info)
        sb-alien:int
      (thread sb-alien:unsigned-int)
      (flavor sb-alien:int)
      (info (* (array sb-alien:int 10)))
      (count (* sb-alien:unsigned-int)))
    (defun rom-thread-cpu-time-nanoseconds (thread)
      ;; SBCL's Darwin thread ID is the Mach port accepted by THREAD-INFO.
      (let ((thread-id (sb-thread:thread-os-tid thread)))
        (when thread-id
          (sb-alien:with-alien ((info (array sb-alien:int 10))
                                (count sb-alien:unsigned-int))
            (setf count 10)
            (let ((result
                    (rom-suite-mach-thread-info
                     thread-id +rom-suite-thread-basic-info+
                     (sb-alien:addr info) (sb-alien:addr count))))
              (unless (zerop result)
                (error "Cannot read ROM worker CPU time: Mach error ~D"
                       result))
              (+ (* 1000000000
                    (+ (sb-alien:deref info 0)
                       (sb-alien:deref info 2)))
                 (* 1000
                    (+ (sb-alien:deref info 1)
                       (sb-alien:deref info 3))))))))))
  #+linux
  (progn
    (sb-alien:define-alien-routine
        ("pthread_getcpuclockid" rom-suite-pthread-getcpuclockid)
        sb-alien:int
      (pthread sb-alien:unsigned-long)
      (clock-id (* sb-alien:int)))
    (sb-alien:define-alien-routine
        ("clock_gettime" rom-suite-clock-gettime)
        sb-alien:int
      (clock-id sb-alien:int)
      (time (* (array sb-alien:long 2))))
    (defun rom-thread-cpu-time-nanoseconds (thread)
      ;; Linux SBCL stores PTHREAD-T in its thread object for this POSIX call.
      (if (sb-thread:thread-os-tid thread)
          (sb-alien:with-alien ((clock-id sb-alien:int)
                                (time (array sb-alien:long 2)))
            (let ((result
                    (rom-suite-pthread-getcpuclockid
                     (sb-thread::thread-os-thread thread)
                     (sb-alien:addr clock-id))))
              (unless (zerop result)
                (error "Cannot get ROM worker CPU clock: pthread error ~D"
                       result))
              (unless (zerop
                       (rom-suite-clock-gettime
                        clock-id (sb-alien:addr time)))
                (error "Cannot read ROM worker CPU clock"))
              (+ (* 1000000000 (sb-alien:deref time 0))
                 (sb-alien:deref time 1))))
          nil)))
  #+(and sbcl (not (or darwin linux)))
  (defun rom-thread-cpu-time-nanoseconds (thread)
    (declare (ignore thread))
    (error "ROM per-thread CPU watchdog is unsupported on this SBCL platform"))
  #+sbcl
  (progn
    (defun make-rom-test-timeout-interrupt (state state-lock label timeout-ms)
      (lambda ()
        (sb-thread:with-mutex (state-lock)
          (case (car state)
            (:running
             (setf (car state) :expired)
             (error "ROM test unit ~A exceeded thread-cpu-time-ms=~D"
                    label timeout-ms))
            (:failed
             (error (cadr state)))))))
    (defun finish-rom-test-timeout (state state-lock)
      (sb-thread:with-mutex (state-lock)
        (setf (car state) :finished
              (cadr state) nil)))
    (defun read-rom-thread-cpu-time-nanoseconds (thread cpu-time-reader)
      (let ((time (funcall cpu-time-reader thread)))
        (unless (and (integerp time) (not (minusp time)))
          (error "ROM worker CPU clock returned an invalid value: ~S" time))
        time)))
  #+sbcl
  (defun call-with-thread-cpu-timeout
      (label thunk timeout-ms
       &optional (cpu-time-reader #'rom-thread-cpu-time-nanoseconds))
    (let* ((target sb-thread:*current-thread*)
           (start (read-rom-thread-cpu-time-nanoseconds target cpu-time-reader))
           (budget-nanoseconds (* timeout-ms 1000000))
           (state (list :running nil))
           (state-lock (sb-thread:make-mutex :name "rom-timeout-state"))
           (stop (sb-thread:make-semaphore))
           (watchdog
             (sb-thread:make-thread
              (lambda ()
                (loop
                  (when (sb-thread:wait-on-semaphore stop :timeout 0.01d0)
                    (return))
                  (unless (sb-thread:thread-alive-p target)
                    (return))
                  (let ((current
                          (handler-case
                              (read-rom-thread-cpu-time-nanoseconds
                               target cpu-time-reader)
                            (error (condition)
                              (when (sb-thread:thread-alive-p target)
                                (let ((notify-p
                                        (sb-thread:with-mutex (state-lock)
                                          (when (eq (car state) :running)
                                            (setf (car state) :failed
                                                  (cadr state) condition)
                                            t))))
                                  (when notify-p
                                    (sb-thread:interrupt-thread
                                     target
                                     (make-rom-test-timeout-interrupt
                                      state state-lock label timeout-ms)))))
                              nil))))
                    (unless current
                      (return))
                    (when (>= (- current start) budget-nanoseconds)
                      (sb-thread:interrupt-thread
                       target
                       (make-rom-test-timeout-interrupt
                        state state-lock label timeout-ms))
                      (return))))))))
      (unwind-protect
           (funcall thunk)
        (finish-rom-test-timeout state state-lock)
        (sb-thread:signal-semaphore stop)
        (sb-thread:join-thread watchdog))))
  (defun call-with-rom-test-timeout
      (label thunk &optional max-frames)
    (let ((timeout-ms (rom-test-cpu-timeout-ms max-frames)))
      #+sbcl
      (call-with-thread-cpu-timeout label thunk timeout-ms)
      #-sbcl
      (funcall thunk))))

(defun rom-worker-count ()
  (positive-environment-integer "CL_NES_ROM_WORKERS"
                                *default-rom-worker-count*))

(defun rom-suite-shard ()
  (let ((name (uiop:getenv "CL_NES_ROM_SUITE_SHARD")))
    (if (null name)
        :all
        (let ((shard (intern (string-upcase name) :keyword)))
          (if (member shard
                      '(:cpu-1 :cpu-2 :cpu-3 :cpu-4 :cpu-5 :cpu-6
                        :ppu-1 :ppu-2 :ppu-3 :ppu-4 :ppu-5 :ppu-6
                        :apu-test :apu-dmc :apu-timing :dma :mapper
                        :accuracy-coin))
              shard
              (error "Unknown ROM suite shard: ~A" name))))))

(defun rom-suite-contracts ()
  (let ((shard (rom-suite-shard)))
    (remove-if-not
     (lambda (contract)
       (let ((id (rom-contract-id contract)))
         (or (eq shard :all)
             (and (eq shard :cpu-1)
                  (member id
                          '("instr-test-v5"
                            "instr-misc-01-abs-x-wrap")
                          :test #'string=))
             (and (eq shard :cpu-6)
                  (member id '("cpu-interrupts-v2-03-nmi-irq")
                          :test #'string=))
             (and (eq shard :cpu-2)
                  (member id
                          '("instr-timing"
                            "instr-test-v5-07-abs-xy"
                            "cpu-interrupts-v2" "cpu-reset-ram"
                            "cpu-interrupts-v2-02-nmi-brk"
                            "instr-test-v5-03-immediate"
                            "instr-test-v5-12-jmp-jsr"
                            "instr-test-v5-16-special")
                          :test #'string=))
             (and (eq shard :cpu-3)
                  (member id
                          '("instr-timing-01"
                            "instr-test-v5-08-ind-x" "cpu-dummy-writes"
                            "instr-misc-04-dummy-reads-apu"
                            "cpu-interrupts-v2-01-cli"
                            "instr-test-v5-02-implied"
                            "instr-test-v5-10-branches"
                            "instr-test-v5-15-brk" "cpu-dummy-reads")
                          :test #'string=))
             (and (eq shard :cpu-4)
                  (member id
                          '("instr-timing-02-branch"
                            "instr-test-v5-09-ind-y" "instr-misc"
                            "cpu-interrupts-v2-04-irq-dma"
                            "cpu-interrupts-v2-05-branch"
                            "cpu-exec-space-ppuio"
                            "instr-misc-02-branch-wrap"
                            "instr-test-v5-04-zero-page"
                            "instr-test-v5-13-rts")
                          :test #'string=))
             (and (eq shard :cpu-5)
                  (member id
                          '("cpu-reset-registers" "cpu-exec-space-apu"
                            "instr-test-v5-05-zp-xy" "instr-test-v5-11-stack"
                            "cpu-dummy-reads-subrom"
                            "instr-misc-03-dummy-reads"
                            "instr-test-v5-01-basics"
                            "instr-test-v5-06-absolute"
                            "instr-test-v5-14-rti")
                          :test #'string=))
             (and (eq shard :ppu-1)
                  (member id
                          '("blargg-ppu-vram-access" "ppu-open-bus"
                            "sprite-hit-07" "sprite-overflow-1")
                          :test #'string=))
             (and (eq shard :ppu-2)
                  (member id
                          '("ppu-read-buffer" "oam-read" "sprite-hit-03"
                            "sprite-hit-08" "sprite-overflow-2")
                          :test #'string=))
             (and (eq shard :ppu-3)
                  (member id
                          '("blargg-ppu-palette-ram"
                            "blargg-ppu-power-up-palette" "ppu-vbl-07"
                            "ppu-vbl-10" "sprite-hit-04" "sprite-hit-09"
                            "sprite-overflow-3")
                          :test #'string=))
             (and (eq shard :ppu-4)
                  (member id
                          '("blargg-ppu-sprite-ram" "ppu-vbl-01"
                            "ppu-vbl-03" "ppu-vbl-05" "ppu-vbl-08"
                            "sprite-hit-01" "sprite-hit-05" "sprite-hit-10"
                            "sprite-overflow-4")
                          :test #'string=))
             (and (eq shard :ppu-5)
                  (member id
                          '("blargg-ppu-vbl-clear-time" "ppu-vbl-02"
                            "ppu-vbl-04" "ppu-vbl-06" "ppu-vbl-09"
                            "sprite-hit-02" "sprite-hit-06" "sprite-hit-11"
                            "sprite-overflow-5")
                          :test #'string=))
             (and (eq shard :ppu-6)
                  (member id '("ppu-vbl-nmi") :test #'string=))
             (and (eq shard :apu-test)
                  (string= id "apu-test"))
             (and (eq shard :apu-dmc)
                  (member id '("apu-dmc-basics" "apu-dmc-rates")
                          :test #'string=))
             (and (eq shard :apu-timing)
                  (and (>= (length id) 10)
                       (string= id "blargg-apu" :end1 10 :end2 10)))
             (eq (rom-contract-category contract) shard))))
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

(progn
  (defun capture-rom-suite-failure (unit thunk)
    (handler-case
        (progn (funcall thunk) nil)
      (error (condition)
        (list (list unit (princ-to-string condition))))))
  (defun capture-rom-contract-failure (contract result)
    (let ((failures
           (capture-rom-suite-failure
            (rom-contract-id contract)
            (lambda () (enforce-ratchet contract result)))))
      (cond
        (failures (values failures nil))
        ((and (eq :known-fail (rom-contract-state contract))
              (not (getf result :passed)))
         (values nil
                 (list (list (rom-contract-id contract)
                             (result-summary contract result)))))
        (t (values nil nil)))))
  (defun run-rom-suite ()
    (let ((results nil)
          (failures nil)
          (known-failures nil)
          (shard (rom-suite-shard))
          (contracts (rom-suite-contracts)))
      (format t "rom-suite shard=~A workers=~D contracts=~D~%"
              shard
              (min (length contracts) (rom-worker-count))
              (length contracts))
      (dolist (entry (run-contracts-parallel contracts))
        (let* ((contract (car entry))
               (result (cdr entry)))
          (multiple-value-bind (contract-failures contract-known-failures)
              (capture-rom-contract-failure contract result)
            (setf failures (nconc failures contract-failures)
                  known-failures (nconc known-failures
                                        contract-known-failures))
            (when contract-failures
              (format *error-output* "ROM failed: ~A~%"
                      (result-summary contract result))))
          (push result results)
          (format t "~A~%" (result-summary contract result))))
      (when (member shard (list :all :accuracy-coin))
        (setf failures
              (nconc failures
                     (capture-rom-suite-failure
                      "accuracy-coin"
                      (function run-accuracy-contract)))))
      (values (nreverse results) failures known-failures))))

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
                       (or (numberp expected)
                           (stringp expected)
                           (and (member protocol '(:text-progress :nametable-text))
                                (consp expected)
                                (every (function stringp) expected)))
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

(progn
  (define-rom-contract-tests)
  (describe-each
   (("multiple lost items"))
   "AccuracyCoin ratchet ~A"
   (scenario)
   (it "reports every lost item on its own line"
     (let ((message
             (handler-case
                 (progn
                   (enforce-accuracy-ratchet
                    '(:id "accuracy-coin"
                      :state :known-fail
                      :ratchet-pass-count 0
                      :ratchet-pass-items ("NMI Overlap IRQ"
                                           "Misaligned OAM behavior"))
                    '(:passed nil :pass-count 0 :items nil))
                   "")
               (error (condition)
                 (princ-to-string condition)))))
       (cl-weave:expect
        (not (null
              (search
               (format nil
                       "item lost: NMI Overlap IRQ~%item lost: Misaligned OAM behavior")
               message)))
        :to-be t))))
  (describe-each
   (("later units"))
   "ROM suite failure collection ~A"
   (scenario)
   (it "records failures and classifies known-fail contracts"
       (let ((visited nil)
             (failures nil))
         (dolist (entry (list (list "first-contract" t)
                              (list "second-contract" t)
                              (list "last-contract" nil)))
           (setf failures
                 (nconc failures
                        (capture-rom-suite-failure
                         (first entry)
                         (lambda ()
                           (push (first entry) visited)
                           (when (second entry)
                             (error "synthetic failure")))))))
         (cl-weave:expect (nreverse visited)
                          :to-equal
                          (list "first-contract"
                                "second-contract"
                                "last-contract"))
         (cl-weave:expect (mapcar (function first) failures)
                          :to-equal (list "first-contract" "second-contract"))
         (let* ((contract (make-rom-contract
                           "known-fail-contract" :cpu "synthetic.nes"
                           :blargg 0 1 :known-fail
                           "STATUS 128; SYNTHETIC FAILED FAILURE"))
                (result (list :passed nil :frames 1
                              :text "synthetic FAILED failure tail"
                              :status 128 :signature t :error nil)))
           (multiple-value-bind (contract-failures known-failures)
               (capture-rom-contract-failure contract result)
             (cl-weave:expect contract-failures :to-be nil)
             (cl-weave:expect (mapcar (function first) known-failures)
                              :to-equal (list "known-fail-contract"))
             (cl-weave:expect
              (not (null
                    (search "text=synthetic FAILED failure tail"
                            (second (first known-failures)))))
              :to-be t)))
         (let* ((contract (make-rom-contract
                           "mismatched-known-fail-contract" :cpu "synthetic.nes"
                           :blargg 0 1 :known-fail
                           "status 128; recorded FAILED failure"))
                (result (list :passed nil :frames 1
                              :text "different FAILED failure"
                              :status 128 :signature t :error nil)))
           (multiple-value-bind (contract-failures known-failures)
               (capture-rom-contract-failure contract result)
             (cl-weave:expect (mapcar (function first) contract-failures)
                              :to-equal (list "mismatched-known-fail-contract"))
             (cl-weave:expect known-failures :to-be nil)
             (cl-weave:expect
              (not (null
                    (search "failure-text mismatch"
                            (second (first contract-failures)))))
              :to-be t)))
         (let* ((contract (make-rom-contract
                           "signature-known-fail" :cpu "synthetic.nes"
                           :blargg 0 1 :known-fail
                           "status 0 but signature mismatch"))
                (result (list :passed nil :frames 1 :text ""
                              :status 0 :signature nil :error nil)))
           (multiple-value-bind (contract-failures known-failures)
               (capture-rom-contract-failure contract result)
             (cl-weave:expect contract-failures :to-be nil)
             (cl-weave:expect (mapcar (function first) known-failures)
                              :to-equal (list "signature-known-fail"))))
         (let* ((contract (make-rom-contract
                           "incomplete-known-fail" :cpu "synthetic.nes"
                           :blargg 0 1 :known-fail
                           "status 128; incomplete at text T+ Clocks"))
                (result (list :passed nil :frames 1
                              :text "T+ Clocks (decimal).00"
                              :status 128 :signature t :error nil)))
           (multiple-value-bind (contract-failures known-failures)
               (capture-rom-contract-failure contract result)
             (cl-weave:expect contract-failures :to-be nil)
             (cl-weave:expect (mapcar (function first) known-failures)
                              :to-equal (list "incomplete-known-fail"))))
         (let* ((contract (make-rom-contract
                           "errored-known-fail" :cpu "synthetic.nes"
                           :blargg 0 1 :known-fail "text=condition signaled"))
                (result (list :passed nil :frames nil
                              :text "condition signaled"
                              :status nil :signature nil
                              :error "synthetic exception")))
           (multiple-value-bind (contract-failures known-failures)
               (capture-rom-contract-failure contract result)
             (cl-weave:expect (mapcar (function first) contract-failures)
                              :to-equal (list "errored-known-fail"))
             (cl-weave:expect known-failures :to-be nil)))
         (let* ((contract (make-rom-contract
                           "unexpectedly-passing-known-fail" :cpu "synthetic.nes"
                           :blargg 0 1 :known-fail "status 0; Passed"))
                (result (list :passed t :frames 1 :text "Passed"
                              :status 0 :signature t :error nil)))
           (multiple-value-bind (contract-failures known-failures)
               (capture-rom-contract-failure contract result)
             (cl-weave:expect (mapcar (function first) contract-failures)
                              :to-equal
                              (list "unexpectedly-passing-known-fail"))
             (cl-weave:expect known-failures :to-be nil)))
         (let* ((contract (make-rom-contract
                           "passing-contract" :cpu "synthetic.nes"
                           :blargg 0 1 :pass "expected pass"))
                (result (list :passed nil :frames 1 :text "actual failure"
                              :status 128 :signature t :error nil)))
           (multiple-value-bind (contract-failures known-failures)
               (capture-rom-contract-failure contract result)
             (cl-weave:expect (mapcar (function first) contract-failures)
                              :to-equal (list "passing-contract"))
             (cl-weave:expect known-failures :to-be nil))))))
  (describe-each
   (("parallel worker load"))
   "ROM per-thread CPU timeout ~A"
   (scenario)
   (it "keeps a bounded per-thread CPU budget"
     (let ((*rom-test-timeout-ms-per-frame* 3)
           (*rom-test-timeout-margin* 1.25d0)
           (*rom-test-timeout-startup-ms* 7))
       (cl-weave:expect (rom-test-cpu-timeout-ms 10 nil)
                        :to-equal 45)
       (cl-weave:expect (rom-test-cpu-timeout-ms 10 "2500")
                        :to-equal 2500)))
   (it "does not charge scheduler time spent sleeping"
     (cl-weave:expect
      (call-with-thread-cpu-timeout
       "sleep probe" (lambda () (sleep 0.1d0) :completed) 25)
      :to-equal :completed))
   (it "does not charge CPU used by a sibling worker"
     (let* ((started (sb-thread:make-semaphore))
            (stop (sb-thread:make-semaphore))
            (sibling
              (sb-thread:make-thread
               (lambda ()
                 (sb-thread:signal-semaphore started)
                 (loop until (sb-thread:try-semaphore stop))))))
       (unwind-protect
            (progn
              (sb-thread:wait-on-semaphore started)
              (let ((real-time-deadline
                      (+ (get-internal-real-time)
                         (* 30 internal-time-units-per-second))))
                (loop until (or
                              (>= (rom-thread-cpu-time-nanoseconds sibling)
                                  25000000)
                              (>= (get-internal-real-time)
                                  real-time-deadline))
                      do (sleep 0.01d0)))
              (cl-weave:expect
               (call-with-thread-cpu-timeout
                "sibling CPU probe"
                (lambda () (sleep 0.3d0) :completed)
                25)
               :to-equal :completed)
              (cl-weave:expect
               (>= (rom-thread-cpu-time-nanoseconds sibling) 25000000)
               :to-be t))
         (sb-thread:signal-semaphore stop)
         (sb-thread:join-thread sibling))))
   (it "propagates CPU clock sampling failures into the worker"
     (let* ((sample-count 0)
            (message
              (handler-case
                  (progn
                    (call-with-thread-cpu-timeout
                     "clock probe"
                     (lambda () (loop))
                     50
                     (lambda (thread)
                       (declare (ignore thread))
                       (if (zerop sample-count)
                           (progn
                             (incf sample-count)
                             0)
                           (error "synthetic CPU clock failure"))))
                    "")
                (error (condition)
                  (princ-to-string condition)))))
       (cl-weave:expect
        (not (null (search "synthetic CPU clock failure" message)))
        :to-be t)))
   (it "expires only when the worker handles the timeout callback"
     (let* ((state (list :running nil))
            (state-lock (sb-thread:make-mutex))
            (message
              (handler-case
                  (progn
                    (funcall
                     (make-rom-test-timeout-interrupt
                      state state-lock "expiry probe" 25))
                    "")
                (error (condition)
                  (princ-to-string condition)))))
       (cl-weave:expect (car state) :to-be :expired)
       (cl-weave:expect
        (not (null (search "thread-cpu-time-ms=25" message)))
        :to-be t)))
   (it "ignores a delayed timeout callback after completion wins the gate"
     (let* ((state (list :running nil))
            (state-lock (sb-thread:make-mutex))
            (callback-started (sb-thread:make-semaphore))
            (deliver-callback (sb-thread:make-semaphore))
            (callback-finished (sb-thread:make-semaphore))
            (callback-error nil)
            (joined-p nil)
            (callback
              (make-rom-test-timeout-interrupt
               state state-lock "late probe" 25))
            (callback-thread
              (sb-thread:make-thread
               (lambda ()
                 (sb-thread:signal-semaphore callback-started)
                 (sb-thread:wait-on-semaphore deliver-callback)
                 (setf callback-error
                       (handler-case
                           (progn (funcall callback) nil)
                         (error (condition) condition)))
                 (sb-thread:signal-semaphore callback-finished)))))
       (unwind-protect
            (progn
              (sb-thread:wait-on-semaphore callback-started)
              (finish-rom-test-timeout state state-lock)
              (sb-thread:signal-semaphore deliver-callback)
              (sb-thread:wait-on-semaphore callback-finished)
              (sb-thread:join-thread callback-thread)
              (setf joined-p t)
              (cl-weave:expect (car state) :to-be :finished)
              (cl-weave:expect callback-error :to-be nil))
         (unless joined-p
           (sb-thread:signal-semaphore deliver-callback)
           (sb-thread:join-thread callback-thread)))))
   (it "interrupts a loop with no frame progress"
     (let ((message
             (handler-case
                 (progn
                   (call-with-thread-cpu-timeout
                    "loop probe" (lambda () (loop)) 50)
                   "")
               (error (condition)
                 (princ-to-string condition)))))
       (cl-weave:expect
        (not (null (search "thread-cpu-time-ms=50" message)))
        :to-be t))))
)

(defun rom-suite-main ()
  (handler-case
      (progn
        (when (member (rom-suite-shard) (list :all :cpu-1))
          (run-rom-suite-table-tests))
        (multiple-value-bind (results failures known-failures)
            (run-rom-suite)
          (declare (ignore results))
          (when (member (rom-suite-shard) (quote (:all :mapper)))
            (setf failures
                  (nconc failures
                         (capture-rom-suite-failure
                          "nestest"
                          (lambda ()
                            (let ((difference
                                    (call-with-rom-test-timeout
                                     "nestest" (function run-nestest-trace))))
                              (when difference
                                (error "nestest required pass: ~A" difference))))))))
          (format *error-output* "ROM suite failures (~D):~%"
                  (length failures))
          (dolist (failure failures)
            (format *error-output*
                    "ROM suite failure unit=~A condition=~A~%"
                    (first failure) (second failure)))
          (format *error-output* "ROM suite known-fail contracts (~D):~%"
                  (length known-failures))
          (dolist (known-failure known-failures)
            (format *error-output*
                    "ROM suite known-fail unit=~A result=~A~%"
                    (first known-failure) (second known-failure)))
          (if failures 1 0)))
    (error (condition)
      (format *error-output* "ROM suite failed: ~A~%" condition)
      1)))
