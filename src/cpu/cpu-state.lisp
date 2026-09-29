(in-package #:cl-nes)

(defconstant +flag-carry+ #x01)
(defconstant +flag-zero+ #x02)
(defconstant +flag-interrupt-disable+ #x04)
(defconstant +flag-decimal+ #x08)
(defconstant +flag-break+ #x10)
(defconstant +flag-unused+ #x20)
(defconstant +flag-overflow+ #x40)
(defconstant +flag-negative+ #x80)

(define-hardware-state cpu
  ((a 0 (unsigned-byte 8))
   (x 0 (unsigned-byte 8))
   (y 0 (unsigned-byte 8))
   (p #x24 (unsigned-byte 8))
   (sp #xFD (unsigned-byte 8))
   (pc 0 (unsigned-byte 16))
   (cycles 0 fixnum)
  ;; CLI/PLP/RTI expose a cleared I flag one instruction before IRQ sampling.
   (irq-delay 0 fixnum)
  ;; A taken, non-page-crossing branch ignores an IRQ asserted on its last
  ;; clock.  The instruction runner consumes this one-boundary marker.
   (irq-poll-delay nil nil)
   (stopped-p nil nil))
  :constructor %make-cpu
  :predicate cpu-instance-p)
