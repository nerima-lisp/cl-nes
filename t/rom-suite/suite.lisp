(in-package #:cl-nes/rom-suite)

(defun result-summary (contract result)
  (format nil "~A passed=~A frames=~A text=~A hash=~A status=~A error=~A"
          (rom-contract-id contract)
          (getf result :passed)
          (getf result :frames)
          (getf result :text)
          (getf result :hash)
          (getf result :status)
          (getf result :error)))

(defun run-contract (contract)
  (let ((path (resolve-rom-path contract)))
    (unless (probe-file path)
      (error "ROM input missing for ~A: ~A" (rom-contract-id contract) path))
    (handler-case
        (case (rom-contract-protocol contract)
          (:blargg (run-blargg-contract path contract))
          (:screen-hash (run-screen-contract path contract))
          (otherwise (error "Unknown ROM protocol ~S" (rom-contract-protocol contract))))
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

(defun run-accuracy-contract ()
  (let ((path (accuracy-coin-path)))
    (unless (and path (probe-file path))
      (error "AccuracyCoin input missing: ~A" path))
    (let* ((result (run-accuracy-coin path *accuracy-coin-contract*))
           (pass-count (getf result :pass-count))
           (baseline 0))
      (when (< pass-count baseline)
        (error "AccuracyCoin ratchet regression: ~D < ~D" pass-count baseline))
      (format t "accuracy-coin pass=~D total=~D fail=~D skip=~D running=~D~%"
              pass-count (getf result :total) (getf result :fail-count)
              (getf result :skip-count) (getf result :running-count))
      result)))

(defun run-rom-suite ()
  (let ((results nil))
    (dolist (contract (rom-contract-table))
      (let ((result (enforce-ratchet contract (run-contract contract))))
        (push result results)
        (format t "~A~%" (result-summary contract result))))
    (run-accuracy-contract)
    (nreverse results)))

(defmacro define-rom-contract-tests ()
  `(progn
     (describe-each
      ,*rom-contract-data*
      "ROM contract ~A"
      (id category path protocol expected max-frames state failure-text mapper)
      (it "has a declarative protocol and bounded execution"
          (unless (and (stringp id) (keywordp category) (stringp path)
                       (or (numberp expected) (stringp expected))
                       (stringp failure-text)
                       (or (null mapper) (keywordp mapper))
                       (member protocol '(:blargg :screen-hash :accuracy-coin))
                       (plusp max-frames)
                       (member state '(:pass :known-fail)))
            (error "invalid ROM contract"))))
     (cl-weave:describe "ROM suite table"
       (it-each
        ,*rom-contract-data*
        "table row ~A"
        (id category path protocol expected max-frames state failure-text mapper)
        (unless (and (stringp id) (keywordp category) (stringp path)
                     (or (numberp expected) (stringp expected))
                     (stringp failure-text)
                     (or (null mapper) (keywordp mapper))
                     (member protocol '(:blargg :screen-hash :accuracy-coin))
                     (plusp max-frames)
                     (member state '(:pass :known-fail)))
          (error "invalid table row"))))))

(define-rom-contract-tests)

(defun rom-suite-main ()
  (handler-case
      (progn
        (run-rom-suite)
        (run-nestest-trace)
        0)
    (error (condition)
      (format *error-output* "ROM suite failed: ~A~%" condition)
      1)))
