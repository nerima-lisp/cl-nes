(in-package #:cl-nes/test)

(describe "condition reports"
  (it "exposes invalid ROM reasons"
    (let ((condition
            (captured-condition
             (lambda () (error 'invalid-rom :reason "bad header")))))
      (expect (invalid-rom-reason condition) :to-equal "bad header")
      (expect (format nil "~A" condition)
              :to-equal "Invalid iNES ROM: bad header")))

  (it "formats mapper and opcode failures"
    (let ((mapper-condition
            (captured-condition
             (lambda () (error 'unsupported-mapper :number 22))))
          (opcode-condition
            (captured-condition
             (lambda ()
               (error 'illegal-opcode :opcode #x02 :address #xC123)))))
      (expect (format nil "~A" mapper-condition)
              :to-equal "Unsupported NES mapper: 22")
      (expect (illegal-opcode-value opcode-condition) :to-be #x02)
      (expect (illegal-opcode-address opcode-condition) :to-be #xC123)
      (expect (format nil "~A" opcode-condition)
              :to-equal "Illegal 6502 opcode #x02 at #xC123"))))
