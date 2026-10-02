(in-package #:cl-nes/test)

(describe "PPU background rendering transitions"
  (it "selects background quadrants"
    (let* ((cartridge (make-fixture-cartridge))
           (ppu (make-ppu cartridge)))
      (ppu-write-register! ppu #x00 #x10)
      (ppu-write-register! ppu #x01 #x06)
      (ppu-write-vram! ppu #x2001 #x01)
      (ppu-write-vram! ppu #x1010 #x80)
      (ppu-write-vram! ppu #x3F01 #x22)
      (multiple-value-bind (color present)
          (cl-nes::%background-pixel ppu 8 0)
        (expect color :to-be #x22)
        (expect present :to-be t))
      (multiple-value-bind (color present)
          (cl-nes::%background-pixel ppu 0 0)
        (expect color :to-be 0)
        (expect present :to-be nil))
      (ppu-write-vram! ppu #x2042 #x01)
      (ppu-write-vram! ppu #x23C0 #xC0)
      (ppu-write-vram! ppu #x3F0D #x33)
      (multiple-value-bind (color present)
          (cl-nes::%background-pixel ppu 16 16)
        (expect color :to-be #x33)
        (expect present :to-be t))))
  (it "packs grayscale and emphasis into dot-rendered pixels"
    (let ((ppu (make-ppu (make-fixture-cartridge))))
      (setf (ppu-mask ppu) #xE1)
      (expect (cl-nes::%ppu-palette-pixel ppu #x2F)
              :to-be (logior #x20 (ash 7 6)))))

  (it "selects the background pattern table for a normal fetch"
    (let ((ppu (make-ppu (make-fixture-cartridge))))
      (setf (ppu-control ppu) #x10
            (cl-nes::ppu-next-tile ppu) 1)
      (ppu-write-vram! ppu #x1010 #xA5)
      (cl-nes::%ppu-background-fetch! ppu 5)
      (expect (cl-nes::ppu-next-pattern-low ppu) :to-be #xA5)))

  (it "selects MMC5 EXRAM tiles only in EXRAM mode one"
    (with-mmc5-cartridge (cart)
      (let ((ppu (make-ppu cart)))
        (cl-nes::cartridge-write-expansion! cart #x5104 0)
        (expect (cl-nes::%ppu-mmc5-exram-tile ppu 0 0) :to-be nil)
        (cl-nes::cartridge-write-expansion! cart #x5104 1)
        (expect (integerp (cl-nes::%ppu-mmc5-exram-tile ppu 0 0))
                :to-be t)))))
