(in-package #:cl-nes/test)

(describe "PPU sprite rendering transitions"
  (it "applies horizontal and vertical sprite flips"
    (let* ((ppu (make-ppu (make-fixture-cartridge)))
           (oam (ppu-oam ppu)))
      (ppu-write-vram! ppu #x0000 #x80)
      (ppu-write-vram! ppu #x3F11 #x21)
      (setf (aref oam 0) 0
            (aref oam 1) 0
            (aref oam 3) 8)
      (flet ((expect-pixel (attributes x y)
               (setf (aref oam 2) attributes)
               (multiple-value-bind (color present behind-background)
                   (cl-nes::%sprite-pixel ppu 0 x y)
                 (declare (ignore behind-background))
                 (expect present :to-be t)
                 (expect color :to-be #x21))))
        (expect-pixel 0 8 1)
        (expect-pixel #x40 15 1)
        (expect-pixel #x80 8 8)
        (expect-pixel #xC0 15 8))))

  (it "selects 8x16 sprite pattern tables and tracks sprite zero hits"
    (let ((sprite-ppu (make-ppu (make-fixture-cartridge))))
      (ppu-write-register! sprite-ppu #x00 #x20)
      (ppu-write-vram! sprite-ppu #x1000 #x80)
      (ppu-write-vram! sprite-ppu #x3F11 #x21)
      (setf (aref (ppu-oam sprite-ppu) 0) 0
            (aref (ppu-oam sprite-ppu) 1) 1
            (aref (ppu-oam sprite-ppu) 2) 0
            (aref (ppu-oam sprite-ppu) 3) 8)
      (multiple-value-bind (color present behind)
          (cl-nes::%sprite-pixel sprite-ppu 0 8 1)
        (expect color :to-be #x21)
        (expect present :to-be t)
        (expect behind :to-be nil))
      (let* ((width 256)
             (height 240)
             (occupied (make-array (* width height)
                                   :element-type 'bit
                                   :initial-element 0))
             (opaque (make-array (* width height)
                                 :element-type 'bit
                                 :initial-element 0))
             (index (+ 8 (* 1 width))))
        (setf (aref opaque index) 1)
        (cl-nes::%draw-sprite-pixel! sprite-ppu 0 8 1 opaque occupied)
        (expect (aref occupied index) :to-be 1)
        (expect (logand (ppu-status sprite-ppu) #x40) :to-be #x40)
        (cl-nes::%draw-sprite-pixel! sprite-ppu 0 8 1 opaque occupied)
        (expect (aref occupied index) :to-be 1)))))
