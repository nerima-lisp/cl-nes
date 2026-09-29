(in-package #:cl-nes)

(defun make-apu (&key memory-reader)
  (%make-apu
   :pulse-1 (%make-apu-pulse :envelope (%make-apu-envelope))
   :pulse-2 (%make-apu-pulse :envelope (%make-apu-envelope))
   :triangle (%make-apu-triangle)
   :noise (%make-apu-noise :envelope (%make-apu-envelope))
   :dmc (%make-apu-dmc)
   :memory-reader memory-reader))
