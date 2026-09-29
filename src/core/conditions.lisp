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
