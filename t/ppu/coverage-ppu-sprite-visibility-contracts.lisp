(in-package #:cl-nes/test)

(describe "Coverage: PPU sprite visibility contracts"
  (it "covers sprite pixel visibility through the dot pipeline"
    (with-fixture-ppu (sprite-ppu (make-fixture-cartridge))
      (ppu-write-register! sprite-ppu 1 #x10)
      (ppu-write-vram! sprite-ppu #x0000 #x80)
      (ppu-write-vram! sprite-ppu #x3F11 #x21)
      (setf (aref (ppu-oam sprite-ppu) 0) 0
            (aref (ppu-oam sprite-ppu) 1) 0
            (aref (ppu-oam sprite-ppu) 2) 0
            (aref (ppu-oam sprite-ppu) 3) 8
            (ppu-control sprite-ppu) 0)
      (multiple-value-bind (color present behind)
          (cl-nes::%sprite-pixel sprite-ppu 0 8 1)
        (expect color :to-be #x21)
        (expect present :to-be t)
        (expect behind :to-be nil))
      (multiple-value-bind (color present behind)
          (cl-nes::%sprite-pixel sprite-ppu 0 0 1)
        (expect color :to-be nil)
        (expect present :to-be nil)
        (expect behind :to-be nil))
      (multiple-value-bind (color present behind)
          (cl-nes::%sprite-pixel sprite-ppu 0 8 0)
        (expect color :to-be nil)
        (expect present :to-be nil)
        (expect behind :to-be nil))
      (multiple-value-bind (color present behind)
          (cl-nes::%sprite-pixel sprite-ppu 0 16 1)
        (expect color :to-be nil)
        (expect present :to-be nil)
        (expect behind :to-be nil))
      (setf (aref (ppu-oam sprite-ppu) 3) 0)
      (multiple-value-bind (color present behind)
          (cl-nes::%sprite-pixel sprite-ppu 0 0 1)
        (expect color :to-be #x21)
        (expect present :to-be t)
        (expect behind :to-be nil))
      (setf (ppu-mask sprite-ppu) 0)
      (multiple-value-bind (color present behind)
          (cl-nes::%sprite-pixel sprite-ppu 0 0 1)
        (expect color :to-be nil)
        (expect present :to-be nil)
        (expect behind :to-be nil))
      (setf (aref (ppu-oam sprite-ppu) 3) 8
            (ppu-mask sprite-ppu) #x10)
      (setf (ppu-mask sprite-ppu) #x18
            (cl-nes::ppu-secondary-oam-count sprite-ppu) 1
            (aref (cl-nes::ppu-sprite-indexes sprite-ppu) 0) 0)
      (expect (cl-nes::%ppu-sprite-pixel-at-dot sprite-ppu 0 1 nil)
              :to-be #x21))))
