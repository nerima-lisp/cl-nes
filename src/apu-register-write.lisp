(in-package #:cl-nes)

(defun apu-write-register! (apu address value)
  (let ((value (logand value #xFF)))
    (%apu-register-write-dispatch apu address)
    value))
