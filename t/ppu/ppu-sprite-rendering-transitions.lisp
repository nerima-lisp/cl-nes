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
      (setf (ppu-mask sprite-ppu) #x18
            (cl-nes::ppu-secondary-oam-count sprite-ppu) 1
            (aref (cl-nes::ppu-sprite-indexes sprite-ppu) 0) 0)
      (expect (cl-nes::%ppu-sprite-pixel-at-dot sprite-ppu 8 1 t)
              :to-be #x21)
      (expect (logand (ppu-status sprite-ppu) #x40) :to-be #x40)))
  (it "fetches the flipped lower tile of an 8x16 sprite"
    (let ((ppu (make-ppu (make-fixture-cartridge))))
      (setf (ppu-control ppu) #x20
            (cl-nes::ppu-scanline ppu) 1
            (cl-nes::ppu-dot ppu) 261
            (cl-nes::ppu-secondary-oam-count ppu) 1)
      (setf (aref (cl-nes::ppu-secondary-oam ppu) 0) 0
            (aref (cl-nes::ppu-secondary-oam ppu) 1) 3
            (aref (cl-nes::ppu-secondary-oam ppu) 2) #x80)
      (ppu-write-vram! ppu #x1037 #xA5)
      (ppu-write-vram! ppu #x103F #x5A)
      (cl-nes::%ppu-clock-pipeline! ppu)
      (setf (cl-nes::ppu-dot ppu) 263)
      (cl-nes::%ppu-clock-pipeline! ppu)
      (expect (aref (cl-nes::ppu-sprite-shift-low ppu) 0) :to-be #xA5)
      (expect (aref (cl-nes::ppu-sprite-shift-high ppu) 0) :to-be #x5A)))

  (it "evaluates 8x8 sprites and selects the alternate pattern table"
    (let ((ppu (make-ppu (make-fixture-cartridge))))
      (setf (ppu-control ppu) #x08
            (cl-nes::ppu-scanline ppu) 1
            (cl-nes::ppu-dot ppu) 257)
      (setf (aref (ppu-oam ppu) 0) 0
            (aref (ppu-oam ppu) 1) 1
      (aref (ppu-oam ppu) 2) 0)
      (cl-nes::%ppu-evaluate-sprites! ppu 1)
      (expect (cl-nes::ppu-secondary-oam-count ppu) :to-be 8)
      (setf (cl-nes::ppu-secondary-oam-count ppu) 0)
      (cl-nes::%ppu-clock-pipeline! ppu)
      (expect (cl-nes::ppu-secondary-oam-count ppu) :to-be 0)))

  (it "flags overflow when a ninth 8x8 sprite is on the scanline"
    (let ((ppu (make-ppu (make-fixture-cartridge))))
      (dotimes (sprite 9)
        (setf (aref (ppu-oam ppu) (* sprite 4)) 0))
      (cl-nes::%ppu-evaluate-sprites! ppu 1)
      (expect (logand (ppu-status ppu) #x20) :to-be #x20)))

  (it "evaluates 8x16 sprites and detects 8x16 overflow"
    (let ((ppu (make-ppu (make-fixture-cartridge))))
      (setf (ppu-control ppu) #x20)
      (dotimes (sprite 9)
        (setf (aref (ppu-oam ppu) (* sprite 4)) 0))
      (cl-nes::%ppu-evaluate-sprites! ppu 1)
      (expect (logand (ppu-status ppu) #x20) :to-be #x20)))
  (it "sets sprite zero hit on the dot where opaque pixels overlap"
    (let ((ppu (make-ppu (make-fixture-cartridge))))
      (ppu-write-register! ppu #x01 #x1A)
      (ppu-write-vram! ppu #x0000 #xFF)
      (ppu-write-vram! ppu #x1000 #xFF)
      (ppu-write-vram! ppu #x2000 0)
      (ppu-write-vram! ppu #x3F01 #x01)
      (ppu-write-vram! ppu #x3F11 #x02)
      (setf (aref (ppu-oam ppu) 0) 0
            (aref (ppu-oam ppu) 1) 0
            (aref (ppu-oam ppu) 2) 0
            (aref (ppu-oam ppu) 3) 65
            (cl-nes::ppu-scanline ppu) 1)
      (ppu-tick! ppu 66)
      (expect (logand (ppu-status ppu) #x40) :to-be #x40))))
