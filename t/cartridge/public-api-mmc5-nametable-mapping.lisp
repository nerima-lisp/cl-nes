(in-package #:cl-nes/test)

(describe "MMC5 mapper nametable mapping surface"
  (it "routes nametable reads through MMC5 nametable modes"
    (with-mmc5-cartridge (cart)
      (let ((ppu (make-ppu cart)))
        (write-mmc5-registers! cart
          (#x5105 #b11100100)
          (#x5106 #x5a)
          (#x5107 2))
        (ppu-write-vram! ppu #x2000 #x11)
        (ppu-write-vram! ppu #x2400 #x22)
        (ppu-write-vram! ppu #x2800 #x33)

        (expect (ppu-read-vram ppu #x2000) :to-be #x11)
        (expect (ppu-read-vram ppu #x2400) :to-be #x22)
        (expect (ppu-read-vram ppu #x2800) :to-be #x33)
        (expect (ppu-read-vram ppu #x2c00) :to-be #x5a)
        (expect (ppu-read-vram ppu #x2fc0) :to-be #xaa))))

  (it "captures scanline state and reports pending IRQ status"
    (with-mmc5-cartridge (cart)
      (write-mmc5-registers! cart
        (#x5203 12)
        (#x5204 #x80))
      (cl-nes::cartridge-clock-scanline! cart 12)
      (expect (cl-nes::cartridge-read-expansion cart #x5204) :to-be #xc0)
      (expect (cl-nes::cartridge-irq-pending-p cart) :to-be nil)))

  (it "reports fill-mode nametable locations through the public reader"
    (with-mmc5-cartridge (cart)
      (let ((ppu (make-ppu cart)))
        (write-mmc5-registers! cart
          (#x5105 #b11111111)
          (#x5106 #x3c)
          (#x5107 1))
        (expect (ppu-read-vram ppu #x2000) :to-be #x3c)
        (expect (ppu-read-vram ppu #x23bf) :to-be #x3c)
        (expect (ppu-read-vram ppu #x23c0) :to-be #x55)))))
