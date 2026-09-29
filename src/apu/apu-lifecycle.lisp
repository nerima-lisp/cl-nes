(in-package #:cl-nes)

(defun apu-console-reset! (apu)
  (%apu-console-reset! apu)
  (setf (apu-frame-reset-delay apu) 3)
  apu)
