(in-package #:cl-nes)

(eval-when (:compile-toplevel :load-toplevel :execute)
  (defparameter +mapper5-expansion-write-register-specs+
    '((#x5100 cartridge-mapper5-prg-mode (logand value 3))
      (#x5101 cartridge-mapper5-chr-mode (logand value 3))
      (#x5102 cartridge-mapper5-prg-ram-protect-1 value)
      (#x5103 cartridge-mapper5-prg-ram-protect-2 value)
      (#x5104 cartridge-mapper5-exram-mode (logand value 3))
      (#x5105 cartridge-mapper5-nametable-mapping value)
      (#x5106 cartridge-mapper5-fill-tile value)
      (#x5107 cartridge-mapper5-fill-attribute (logand value 3))
      (#x5200 cartridge-mapper5-split-control value)
      (#x5201 cartridge-mapper5-split-scroll value)
      (#x5202 cartridge-mapper5-split-bank value)
      (#x5203 cartridge-mapper5-irq-scanline value)
      (#x5205 cartridge-mapper5-multiplier-a value)
      (#x5206 cartridge-mapper5-multiplier-b value)))

  (defparameter +mapper5-expansion-read-register-specs+
    '((#x5205
       (ldb (byte 8 0)
            (* (cartridge-mapper5-multiplier-a cartridge)
               (cartridge-mapper5-multiplier-b cartridge))))
      (#x5206
       (ldb (byte 8 8)
            (* (cartridge-mapper5-multiplier-a cartridge)
               (cartridge-mapper5-multiplier-b cartridge)))))))
