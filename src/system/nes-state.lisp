(in-package #:cl-nes)

(defstruct (nes
            (:constructor %make-nes
                (cpu bus ppu apu)))
  cpu
  bus
  ppu
  apu)
