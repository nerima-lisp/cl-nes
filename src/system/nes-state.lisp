(in-package #:cl-nes)
(declaim (special *nes-step-nmi-poll-seen-p*))

(define-hardware-state nes
  ((cpu nil nil)
   (bus nil nil)
   (ppu nil nil)
   (apu nil nil)
   (audio-stream nil nil)
   (irq-line-sample-p nil nil)
   (irq-seen-p nil nil)
   (irq-seen-before-last-p nil nil)
   (nmi-hijacked-p nil nil)
   (master-clock 0 fixnum)
   (ppu-phase-offset 1 fixnum))
  :constructor %make-nes
  :exclude (cpu bus ppu apu audio-stream))
