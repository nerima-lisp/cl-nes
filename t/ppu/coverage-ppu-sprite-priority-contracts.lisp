(in-package #:cl-nes/test)

(describe "Coverage: PPU sprite priority contracts"
  (it "covers pattern-bank selection, 8x16 sprites, and priority"
    (with-fixture-ppu (sprite-ppu (make-fixture-cartridge))
      (ppu-write-register! sprite-ppu 1 #x10)
      (ppu-write-vram! sprite-ppu #x0000 #x80)
      (ppu-write-vram! sprite-ppu #x3F11 #x21)
      (setf (aref (ppu-oam sprite-ppu) 0) 0
            (aref (ppu-oam sprite-ppu) 1) 0
            (aref (ppu-oam sprite-ppu) 2) 0
            (aref (ppu-oam sprite-ppu) 3) 8)
      (ppu-write-vram! sprite-ppu #x1000 #x80)
      (setf (ppu-control sprite-ppu) #x08)
      (multiple-value-bind (color present behind)
          (cl-nes::%sprite-pixel sprite-ppu 0 8 1)
        (expect color :to-be #x21)
        (expect present :to-be t)
        (expect behind :to-be nil))
      (setf (ppu-control sprite-ppu) #x20
            (aref (ppu-oam sprite-ppu) 1) 1
            (aref (ppu-oam sprite-ppu) 2) #xE0)
      (ppu-write-vram! sprite-ppu #x1007 #x01)
      (ppu-write-vram! sprite-ppu #x3F11 #x2A)
      (multiple-value-bind (color present behind)
          (cl-nes::%sprite-pixel sprite-ppu 0 8 9)
        (expect color :to-be #x2A)
        (expect present :to-be t)
        (expect behind :to-be t)))))
