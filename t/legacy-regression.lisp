(in-package #:cl-nes/test)

(describe "legacy regression corpus"
  (it "runs every assertion through the ASDF-loaded legacy corpus"
    (multiple-value-bind (passed failed)
        (uiop:symbol-call :cl-nes/test-runner :run-legacy-tests)
      (expect failed :to-be 0)
      (expect passed :to-be 181))))
