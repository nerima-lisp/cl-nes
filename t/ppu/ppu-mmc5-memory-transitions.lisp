(in-package #:cl-nes/test)

(describe "PPU MMC5 memory transitions"
  (it "routes MMC5 nametables through CIRAM, EXRAM, and fill"
    (let* ((cartridge (make-patterned-cartridge
                       :mapper 5
                       :prg-banks 16
                       :chr-banks 16))
           (ppu (make-ppu cartridge)))
      (cl-nes::cartridge-write-expansion! cartridge #x5105 #xE4)
      (cl-nes::cartridge-write-expansion! cartridge #x5106 #xAA)
      (cl-nes::cartridge-write-expansion! cartridge #x5107 2)
      (ppu-write-vram! ppu #x2000 #x11)
      (ppu-write-vram! ppu #x2400 #x22)
      (ppu-write-vram! ppu #x2800 #x33)
      (expect (ppu-read-vram ppu #x2000) :to-be #x11)
      (expect (ppu-read-vram ppu #x2400) :to-be #x22)
      (expect (ppu-read-vram ppu #x2800) :to-be #x33)
      (expect (ppu-read-vram ppu #x2C00) :to-be #xAA)
      (ppu-write-vram! ppu #x2C00 #x55)
      (expect (ppu-read-vram ppu #x2C00) :to-be #xAA)))

  (it "activates the MMC5 split window with split scroll"
    (let* ((cartridge (make-patterned-cartridge
                       :mapper 5
                       :prg-banks 16
                       :chr-banks 16))
           (ppu (make-ppu cartridge)))
      (setf (cl-nes::ppu-scanline ppu) 10)
      (cl-nes::cartridge-write-expansion! cartridge #x5200 #x84)
      (cl-nes::cartridge-write-expansion! cartridge #x5201 3)
      (multiple-value-bind (active-p split-x split-y)
          (cl-nes::%ppu-mmc5-split-state ppu 17)
        (expect active-p :to-be t)
        (expect split-x :to-be 2)
        (expect split-y :to-be 13))
      (multiple-value-bind (active-p split-x split-y)
          (cl-nes::%ppu-mmc5-split-state ppu 41)
        (expect active-p :to-be nil)
        (expect split-x :to-be 0)
        (expect split-y :to-be 0)))))
