(in-package #:cl-nes)

(defun apu-set-memory-reader! (apu reader)
  "Set the function used by the DMC to read the CPU address space."
  (setf (apu-memory-reader apu) reader)
  apu)
