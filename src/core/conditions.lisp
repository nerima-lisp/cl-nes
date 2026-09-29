(in-package #:cl-nes)

(define-condition nes-error (error)
  ())

(define-condition invalid-rom (nes-error)
  ((reason :initarg :reason :reader invalid-rom-reason))
  (:report (lambda (condition stream)
             (format stream "Invalid iNES ROM: ~A"
                     (invalid-rom-reason condition)))))

(define-condition unsupported-mapper (nes-error)
  ((number :initarg :number :reader unsupported-mapper-number))
  (:report (lambda (condition stream)
             (format stream "Unsupported NES mapper: ~D"
                     (unsupported-mapper-number condition)))))

(define-condition illegal-opcode (nes-error)
  ((opcode :initarg :opcode :reader illegal-opcode-value)
   (address :initarg :address :reader illegal-opcode-address))
  (:report (lambda (condition stream)
             (format stream "Illegal 6502 opcode #x~2,'0X at #x~4,'0X"
                     (illegal-opcode-value condition)
                     (illegal-opcode-address condition)))))
