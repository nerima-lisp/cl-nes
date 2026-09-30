(in-package #:cl-nes/test)

(describe "condition reports"
  (it "exposes invalid ROM reasons"
    (let ((condition
            (captured-condition
             (lambda () (error 'invalid-rom :reason "bad header")))))
      (expect (invalid-rom-reason condition) :to-equal "bad header")
      (expect (format nil "~A" condition)
              :to-equal "Invalid iNES ROM: bad header")))

  (it "formats mapper failures"
    (let ((mapper-condition
            (captured-condition
             (lambda () (error 'unsupported-mapper :number 22)))))
      (expect (format nil "~A" mapper-condition)
              :to-equal "Unsupported NES mapper: 22"))))
