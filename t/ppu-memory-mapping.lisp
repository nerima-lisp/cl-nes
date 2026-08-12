(in-package #:cl-nes/test)

(describe "PPU nametable and VRAM mapping"
  (it "applies horizontal, vertical, single-screen, and four-screen nametable mapping"
    (with-ppu (horizontal (make-state-transition-cartridge))
      (write-vram-values horizontal
        (#x2000 #x11))
      (expect-vram-values horizontal
                          '((#x2400 #x11))))
    (with-ppu (vertical
               (make-state-transition-cartridge
                :mirroring :vertical))
      (write-vram-values vertical
        (#x2000 #x22)
        (#x2400 #x33))
      (expect-vram-values vertical
                          '((#x2000 #x22)
                            (#x2400 #x33))))
    (with-ppu (single-lower
               (make-state-transition-cartridge
                :mirroring :single-screen-lower))
      (write-vram-values single-lower
        (#x2000 #x66))
      (expect-vram-values single-lower
                          '((#x2400 #x66))))
    (with-ppu (single-upper
               (make-state-transition-cartridge
                :mirroring :single-screen-upper))
      (write-vram-values single-upper
        (#x2400 #x77))
      (expect-vram-values single-upper
                          '((#x2000 #x77))))
    (with-ppu (four-screen
               (make-state-transition-cartridge
                :four-screen-p t))
      (write-vram-values four-screen
        (#x2000 #x44)
        (#x2800 #x55)
        (#x3F10 #x66))
      (expect-vram-values four-screen
                          '((#x2000 #x44)
                            (#x2800 #x55)
                            (#x3F00 #x66)))))
  (it "routes MMC5 nametables through CIRAM, EXRAM, and fill"
    (with-mmc5-cartridge (cartridge)
      (let ((ppu (make-ppu cartridge)))
        (write-expansion-registers cartridge
          (#x5105 #xE4)
          (#x5106 #xAA)
          (#x5107 2))
        (write-vram-values ppu
          (#x2000 #x11)
          (#x2400 #x22)
          (#x2800 #x33))
        (expect-vram-values ppu
                            '((#x2000 #x11)
                              (#x2400 #x22)
                              (#x2800 #x33)
                              (#x2C00 #xAA)))
        (ppu-write-vram! ppu #x2C00 #x55)
        (expect (ppu-read-vram ppu #x2C00) :to-be #xAA)))))
