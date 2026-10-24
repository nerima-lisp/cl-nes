(in-package #:cl-nes/test)

(describe "Coverage: PPU sprite visibility contracts"
  (it "covers sprite pixel visibility through the dot pipeline"
    (with-fixture-ppu (sprite-ppu (make-fixture-cartridge))
      (ppu-write-register! sprite-ppu 1 #x14)
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
      (setf (cl-nes::ppu-secondary-oam-count sprite-ppu) 1
            (cl-nes::ppu-sprite-render-count sprite-ppu) 1
            (aref (cl-nes::ppu-sprite-indexes sprite-ppu) 0) 0
            (cl-nes::ppu-rendering-mask-valid-p sprite-ppu) nil
            (ppu-mask sprite-ppu) #x10)
      (expect (cl-nes::%ppu-sprite-pixel-at-dot sprite-ppu 0 1 nil)
              :to-be nil)
      (setf (ppu-mask sprite-ppu) #x14)
      (expect (cl-nes::%ppu-sprite-pixel-at-dot sprite-ppu 0 1 nil)
              :to-be #x21)
      (setf (ppu-mask sprite-ppu) #x04)
      (expect (cl-nes::%ppu-sprite-pixel-at-dot sprite-ppu 0 1 nil)
              :to-be nil)
      (setf (aref (cl-nes::ppu-sprite-shift-low sprite-ppu) 0) #x80
            (aref (cl-nes::ppu-sprite-shift-high sprite-ppu) 0) 0
            (aref (cl-nes::ppu-sprite-attributes sprite-ppu) 0) 0
            (ppu-mask sprite-ppu) #x10)
      (expect (cl-nes::%ppu-sprite-pixel-at-shifts sprite-ppu 0 nil)
              :to-be nil)
      (setf (ppu-mask sprite-ppu) #x14)
      (expect (cl-nes::%ppu-sprite-pixel-at-shifts sprite-ppu 0 nil)
              :to-be #x21)
      (setf (ppu-mask sprite-ppu) #x04)
      (expect (cl-nes::%ppu-sprite-pixel-at-shifts sprite-ppu 0 nil)
              :to-be nil)
      (setf (aref (ppu-oam sprite-ppu) 3) 8
            (ppu-mask sprite-ppu) #x10)
      (expect (cl-nes::%ppu-sprite-pixel-at-dot sprite-ppu 8 1 nil)
              :to-be #x21))))
