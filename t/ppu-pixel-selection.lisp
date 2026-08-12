(in-package #:cl-nes/test)

(describe "PPU pixel selection"
  (it "applies horizontal and vertical sprite flips"
    (with-fixture-ppu (ppu)
      (write-vram-values ppu
        (#x0000 #x80)
        (#x3F11 #x21))
      (write-oam-values ppu
        (0 0)
        (1 0)
        (3 8))
      (flet ((expect-flipped-sprite (attributes x y)
               (write-oam-values ppu
                 (2 attributes))
               (expect-sprite-pixel (ppu 0 x y) #x21 t nil)))
        (expect-flipped-sprite 0 8 1)
        (expect-flipped-sprite #x40 15 1)
        (expect-flipped-sprite #x80 8 8)
        (expect-flipped-sprite #xC0 15 8))))
  (it "selects background quadrants and 8x16 sprite pattern tables"
    (with-fixture-ppu (ppu)
      (write-ppu-registers ppu
        (#x00 #x10)
        (#x01 #x06))
      (write-vram-values ppu
        (#x2001 #x01)
        (#x1010 #x80)
        (#x3F01 #x22))
      (expect-background-pixel (ppu 8 0) #x22 t)
      (expect-background-pixel (ppu 0 0) 0 nil)
      (write-vram-values ppu
        (#x2042 #x01)
        (#x23C0 #xC0)
        (#x3F0D #x33))
      (expect-background-pixel (ppu 16 16) #x33 t)
      (with-fixture-ppu (sprite-ppu)
        (write-ppu-registers sprite-ppu
          (#x00 #x20))
        (write-vram-values sprite-ppu
          (#x1000 #x80)
          (#x3F11 #x21))
        (write-oam-values sprite-ppu
          (0 0)
          (1 1)
          (2 0)
          (3 8))
        (expect-sprite-pixel (sprite-ppu 0 8 1) #x21 t nil)
        (with-screen-bits (occupied opaque)
          (let ((index (+ 8 cl-nes::+ppu-width+)))
            (setf (aref opaque index) 1)
            (cl-nes::%draw-sprite-pixel! sprite-ppu 0 8 1 opaque occupied)
            (expect (aref occupied index) :to-be 1)
            (expect (logand (ppu-status sprite-ppu) #x40) :to-be #x40)
            (cl-nes::%draw-sprite-pixel! sprite-ppu 0 8 1 opaque occupied)
            (expect (aref occupied index) :to-be 1)))))))
