(in-package #:cl-nes)

(defstruct (nes
            (:constructor %make-nes
                (cpu bus ppu apu)))
  cpu
  bus
  ppu
  apu
  (irq-seen-p nil)
  (irq-seen-before-last-p nil)
  (nmi-hijacked-p nil))
