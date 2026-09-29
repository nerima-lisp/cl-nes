(in-package #:cl-nes)

(defconstant +button-a+ #x01)
(defconstant +button-b+ #x02)
(defconstant +button-select+ #x04)
(defconstant +button-start+ #x08)
(defconstant +button-up+ #x10)
(defconstant +button-down+ #x20)
(defconstant +button-left+ #x40)
(defconstant +button-right+ #x80)

(define-hardware-state controller
  ((buttons 0 (unsigned-byte 8))
   (strobe nil nil)
   (shift 0 (unsigned-byte 8))
   (read-count 0 fixnum))
  :constructor %make-controller)
