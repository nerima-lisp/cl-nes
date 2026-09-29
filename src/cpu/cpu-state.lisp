(in-package #:cl-nes)

(defconstant +flag-carry+ #x01)
(defconstant +flag-zero+ #x02)
(defconstant +flag-interrupt-disable+ #x04)
(defconstant +flag-decimal+ #x08)
(defconstant +flag-break+ #x10)
(defconstant +flag-unused+ #x20)
(defconstant +flag-overflow+ #x40)
(defconstant +flag-negative+ #x80)

(defstruct (cpu
            (:constructor %make-cpu
                (&key (a 0) (x 0) (y 0) (p #x24) (sp #xFD) (pc 0)
                      (irq-delay 0)
                      (irq-poll-delay nil)))
            (:predicate cpu-instance-p))
  (a a :type (unsigned-byte 8))
  (x x :type (unsigned-byte 8))
  (y y :type (unsigned-byte 8))
  (p p :type (unsigned-byte 8))
  (sp sp :type (unsigned-byte 8))
  (pc pc :type (unsigned-byte 16))
  (cycles 0 :type fixnum)
  ;; CLI/PLP/RTI expose a cleared I flag one instruction before IRQ sampling.
  (irq-delay irq-delay :type fixnum)
  ;; A taken, non-page-crossing branch ignores an IRQ asserted on its last
  ;; clock.  The instruction runner consumes this one-boundary marker.
  (irq-poll-delay irq-poll-delay)
  (stopped-p nil))
