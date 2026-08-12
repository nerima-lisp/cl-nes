(in-package #:cl-nes)

(defparameter +cpu-interrupt-vectors+
  '((:nmi . #xFFFA)
    (:irq . #xFFFE)))

(defconstant +cpu-reset-vector-address+ #xFFFC)

(defparameter +cpu-reset-state-specs+
  '((cpu-a 0)
    (cpu-x 0)
    (cpu-y 0)
    (cpu-p #x24)
    (cpu-sp #xFD)
    (cpu-cycles 0)
    (cpu-irq-delay 0)
    (cpu-irq-poll-delay nil)
    (cpu-stopped-p nil)))
