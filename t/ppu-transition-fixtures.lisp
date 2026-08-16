(in-package #:cl-nes/test)

(defun make-state-transition-cartridge
    (&key (mirroring :horizontal) four-screen-p)
  (make-cartridge
   :prg-rom (make-array #x8000
                        :element-type '(unsigned-byte 8)
                        :initial-element 0)
   :mirroring mirroring
   :four-screen-p four-screen-p
   :chr-writable-p t))
