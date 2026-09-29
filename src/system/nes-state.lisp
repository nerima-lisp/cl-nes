(in-package #:cl-nes)

(define-hardware-state nes
  ((cpu nil nil)
   (bus nil nil)
   (ppu nil nil)
   (apu nil nil)
   (audio-stream nil nil)
   (irq-seen-p nil nil)
   (irq-seen-before-last-p nil nil)
   (nmi-hijacked-p nil nil))
  :constructor %make-nes
  :exclude (cpu bus ppu apu audio-stream))
