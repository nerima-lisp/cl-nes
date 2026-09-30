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
        (case (rom-contract-protocol contract)
          (:blargg (run-blargg-contract path contract))
          (:ram-result (run-ram-result-contract path contract))
          (:text-progress (run-text-progress-contract path contract))
          (:nametable-text (run-nametable-text-contract path contract))
          (:mmc1-a12 (run-mmc1-a12-contract path contract))
          (otherwise (error "Unknown ROM protocol ~S"
                            (rom-contract-protocol contract))))
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

(defun run-accuracy-contract ()
  (let ((path (accuracy-coin-path)))
    (unless (and path (probe-file path))
      (error "AccuracyCoin input missing: ~A" path))
    (let* ((contract *accuracy-coin-contract*)
           (result (run-accuracy-coin path contract))
           (pass-count (getf result :pass-count)))
      (enforce-accuracy-ratchet contract result)
      (format t "accuracy-coin pass=~D total=~D fail=~D skip=~D running=~D~%"
              pass-count (getf result :total) (getf result :fail-count)
              (getf result :skip-count) (getf result :running-count))
      (format t "accuracy-coin categories=~S~%"
              (getf result :category-pass-counts))
      result)))

(defun run-rom-suite ()
  (let ((results nil))
    (dolist (contract (rom-contract-table))
      (let ((result (enforce-ratchet contract (run-contract contract))))
        (push result results)
        (format t "~A~%" (result-summary contract result))))
    (run-accuracy-contract)
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
       result-address running-value reset-frame)
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
                       (or (null reset-frame) (plusp reset-frame))
                       (member state '(:pass :known-fail)))
            (error "invalid ROM contract"))))
     (cl-weave:describe "ROM suite table"
       (it-each
        ,*rom-contract-test-data*
        "table row ~A"
        (id category path protocol expected max-frames state failure-text mapper
         result-address running-value reset-frame)
        (unless (and (stringp id) (stringp path))
          (error "invalid table row"))))))

(define-rom-contract-tests)

(defun rom-suite-main ()
  (handler-case
      (progn
        (run-rom-suite-table-tests)
        (run-rom-suite)
        (let ((difference (run-nestest-trace)))
          (when difference
            (error "nestest required pass: ~A" difference)))
        0)
    (error (condition)
      (format *error-output* "ROM suite failed: ~A~%" condition)
      1)))
