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

(define-condition cartridge-battery-error (nes-error)
  ((reason :initarg :reason :reader cartridge-battery-error-reason)
   (expected-size :initarg :expected-size
                  :reader cartridge-battery-error-expected-size)
   (actual-size :initarg :actual-size
                :reader cartridge-battery-error-actual-size))
  (:report (lambda (condition stream)
             (format stream "Cartridge battery error (~A): expected ~D bytes, got ~D"
                     (cartridge-battery-error-reason condition)
                     (cartridge-battery-error-expected-size condition)
                     (cartridge-battery-error-actual-size condition)))))
