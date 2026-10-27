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
      (setf (ppu-mask sprite-ppu) #x10
            (cl-nes::ppu-secondary-oam-count sprite-ppu) 1
            (cl-nes::ppu-sprite-render-count sprite-ppu) 1
            (aref (cl-nes::ppu-sprite-indexes sprite-ppu) 0) 0)
      (expect (cl-nes::%ppu-sprite-pixel-at-dot sprite-ppu 8 1 t)
              :to-be #x21)
      (expect (logand (ppu-status sprite-ppu) #x40) :to-be #x40)))
  (it "fetches sprite pattern rows on visible and pre-render scanlines"
    (let ((ppu (make-ppu (make-fixture-cartridge))))
      (setf (ppu-control ppu) #x20
            (cl-nes::ppu-scanline ppu) 1
            (cl-nes::ppu-dot ppu) 261
            (cl-nes::ppu-secondary-oam-count ppu) 1)
      (setf (aref (cl-nes::ppu-secondary-oam ppu) 0) 0
            (aref (cl-nes::ppu-secondary-oam ppu) 1) 3
            (aref (cl-nes::ppu-secondary-oam ppu) 2) #x80)
      (ppu-write-vram! ppu #x1036 #xA5)
      (ppu-write-vram! ppu #x103E #x5A)
      (cl-nes::%ppu-clock-pipeline! ppu)
      (expect (aref (cl-nes::ppu-sprite-shift-low ppu) 0) :to-be 0)
      (setf (cl-nes::ppu-dot ppu) 262)
      (cl-nes::%ppu-clock-pipeline! ppu)
      (expect (aref (cl-nes::ppu-sprite-shift-low ppu) 0) :to-be #xA5)
      (setf (cl-nes::ppu-dot ppu) 263)
      (cl-nes::%ppu-clock-pipeline! ppu)
      (expect (cl-nes::ppu-address-bus ppu) :to-be #x103E)
      (setf (cl-nes::ppu-dot ppu) 264)
      (cl-nes::%ppu-clock-pipeline! ppu)
      (expect (aref (cl-nes::ppu-sprite-shift-low ppu) 0) :to-be #xA5)
      (expect (aref (cl-nes::ppu-sprite-shift-high ppu) 0) :to-be #x5A))
    (let ((ppu (make-ppu (make-fixture-cartridge))))
      (setf (ppu-control ppu) 0
            (cl-nes::ppu-scanline ppu) 261
            (cl-nes::ppu-secondary-oam-count ppu) 1)
      (setf (aref (cl-nes::ppu-secondary-oam ppu) 0) 0
            (aref (cl-nes::ppu-secondary-oam ppu) 1) #xC6
            (aref (cl-nes::ppu-secondary-oam ppu) 2) 0
            (aref (cl-nes::ppu-secondary-oam ppu) 3) #x80)
      (ppu-write-vram! ppu #x0C65 #x80)
      (ppu-write-vram! ppu #x0C6D #x80)
      (cl-nes::%ppu-sprite-fetch! ppu 261 0)
      (expect (cl-nes::ppu-address-bus ppu) :to-be #x0C65)
      (cl-nes::%ppu-sprite-fetch! ppu 262 0)
      (expect (aref (cl-nes::ppu-sprite-shift-low ppu) 0) :to-be #x80)
      (cl-nes::%ppu-sprite-fetch! ppu 263 0)
      (cl-nes::%ppu-sprite-fetch! ppu 264 0)
      (expect (aref (cl-nes::ppu-sprite-shift-high ppu) 0) :to-be #x80)))

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
  (it "does not flag overflow for offscreen Y=255 sprites"
    (let ((ppu (make-ppu (make-fixture-cartridge))))
      (dotimes (sprite 64)
        (setf (aref (ppu-oam ppu) (* sprite 4)) #xFF))
      (cl-nes::%ppu-evaluate-sprites! ppu 0)
      (expect (cl-nes::ppu-secondary-oam-count ppu) :to-be 0)
      (expect (logand (ppu-status ppu) #x20) :to-be 0)))

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
            (cl-nes::ppu-scanline ppu) 1
            (cl-nes::ppu-sprite-render-count ppu) 1
            (aref (cl-nes::ppu-sprite-indexes ppu) 0) 0
            (aref (cl-nes::ppu-sprite-x-counter ppu) 0) 65
            (aref (cl-nes::ppu-sprite-counter-counting ppu) 0) t
            (aref (cl-nes::ppu-sprite-shift-low ppu) 0) #xFF
            (aref (cl-nes::ppu-sprite-shift-high ppu) 0) #xFF
            (aref (cl-nes::ppu-sprite-attributes ppu) 0) 0)
      (ppu-tick! ppu 66)
      (expect (logand (ppu-status ppu) #x40) :to-be #x40)))
  (it "starts sprite evaluation at OAMADDR and retains the original OAM index"
  (let* ((ppu (make-ppu (make-fixture-cartridge)))
         (oam (ppu-oam ppu))
         (secondary (cl-nes::ppu-secondary-oam ppu)))
    (fill oam #xFF)
    (setf (ppu-oam-address ppu) #x81
          (ppu-mask ppu) #x10
          (aref oam #x81) 0
          (aref oam #x82) #xE3
          (aref oam #x83) 0
          (aref oam #x84) 8)
    (loop for dot from 65 to 72
          do (cl-nes::%ppu-evaluate-sprites! ppu 1 dot))
    (expect (cl-nes::ppu-secondary-oam-count ppu) :to-be 1)
    (expect (aref secondary 0) :to-be 0)
    (expect (aref secondary 1) :to-be #xE3)
    (expect (aref secondary 2) :to-be 0)
    (expect (aref secondary 3) :to-be 8)
    (expect (ppu-oam-address ppu) :to-be #x85)
    (setf (cl-nes::ppu-sprite-render-count ppu) 1
          (aref (cl-nes::ppu-sprite-indexes ppu) 0) 32
          (aref (cl-nes::ppu-sprite-x-counter ppu) 0) 0
          (aref (cl-nes::ppu-sprite-shift-low ppu) 0) #x80
          (aref (cl-nes::ppu-sprite-shift-high ppu) 0) 0
          (aref (cl-nes::ppu-sprite-attributes ppu) 0) 0)
    (cl-nes::%ppu-sprite-pixel-at-shifts ppu 8 t)
    (expect (logand (ppu-status ppu) #x40) :to-be 0)
    (setf (cl-nes::ppu-scanline ppu) 0
          (cl-nes::ppu-dot ppu) 257
          (ppu-oam-address ppu) #x80)
    (cl-nes::%ppu-clock-pipeline! ppu)
    (expect (ppu-oam-address ppu) :to-be 0)
    (setf (ppu-mask ppu) 0
          (cl-nes::ppu-dot ppu) 0
          (cl-nes::ppu-sprite-render-count ppu) 1
          (aref (cl-nes::ppu-sprite-x-counter ppu) 0) 1
          (aref (cl-nes::ppu-sprite-counter-counting ppu) 0) t
          (aref (cl-nes::ppu-sprite-shift-low ppu) 0) #x80)
    (ppu-tick! ppu)
    (expect (aref (cl-nes::ppu-sprite-x-counter ppu) 0) :to-be 0)
    (expect (aref (cl-nes::ppu-sprite-shift-low ppu) 0) :to-be #x80)
    (setf (ppu-mask ppu) #x10)
    (ppu-tick! ppu)
    (progn
      (expect (aref (cl-nes::ppu-sprite-shift-low ppu) 0) :to-be 0)
      (let ((render-ppu (make-ppu)))
        (setf (ppu-mask render-ppu) #x14
              (cl-nes::ppu-scanline render-ppu) 0
              (cl-nes::ppu-dot render-ppu) 1
              (cl-nes::ppu-sprite-evaluation-index render-ppu) 0
              (cl-nes::ppu-sprite-evaluation-active-p render-ppu) t
              (cl-nes::ppu-sprite-render-count render-ppu) 1
              (aref (ppu-oam render-ppu) 0) #xFF
              (aref (cl-nes::ppu-sprite-indexes render-ppu) 0) 0
              (aref (cl-nes::ppu-sprite-x-counter render-ppu) 0) 0
              (aref (cl-nes::ppu-sprite-counter-counting render-ppu) 0) nil
              (aref (cl-nes::ppu-sprite-shift-low render-ppu) 0) #x80
              (aref (cl-nes::ppu-sprite-shift-high render-ppu) 0) 0
              (aref (cl-nes::ppu-sprite-attributes render-ppu) 0) 0)
        (ppu-write-vram! render-ppu #x3F11 #x02)
        (cl-nes::%ppu-render-visible-dot! render-ppu)
        (expect (aref (cl-nes::ppu-framebuffer render-ppu) 0) :to-be #x02)))))
  (it "reads OAM[252] at the first empty sprite fetch callback dot"
    (let* ((ppu (make-ppu (make-fixture-cartridge)))
           (oam (ppu-oam ppu))
           (secondary (cl-nes::ppu-secondary-oam ppu)))
      (setf (ppu-mask ppu) #x18
            (cl-nes::ppu-scanline ppu) 128
            (cl-nes::ppu-dot ppu) 257
            (ppu-oam-address ppu) 0
            (cl-nes::ppu-sprite-evaluation-n ppu) 26
            (cl-nes::ppu-sprite-evaluation-m ppu) 0
            (cl-nes::ppu-sprite-evaluation-latch ppu) #x9B
            (cl-nes::ppu-sprite-evaluation-done-p ppu) t
            (cl-nes::ppu-secondary-oam-count ppu) 2
            (aref oam 0) #xFF
            (aref oam #xFC) #x03
            (aref secondary 0) #x7F
            (aref secondary 1) #x7E
            (aref secondary 2) #x7D
            (aref secondary 3) #x7C
            (aref secondary 4) #x7B
            (aref secondary 5) #x7A
            (aref secondary 6) #x79
            (aref secondary 7) #x78)
      (expect (ppu-read-register ppu 4 t) :to-be #x7F)
      (setf (cl-nes::ppu-dot ppu) 265)
      (expect (ppu-read-register ppu 4 t) :to-be #x7B)
      (setf (cl-nes::ppu-dot ppu) 272)
      (expect (cl-nes::ppu-secondary-oam-count ppu) :to-be 2)
      (expect (aref secondary 0) :to-be #x7F)
      (expect (aref secondary 1) :to-be #x7E)
      (expect (aref secondary 2) :to-be #x7D)
      (expect (aref secondary 3) :to-be #x7C)
      (expect (aref secondary 7) :to-be #x78)
      (expect (ppu-oam-address ppu) :to-be 0)
      (expect (ppu-read-register ppu 4 t) :to-be #x03)
      (loop for dot from 273 to 275
            do (setf (cl-nes::ppu-dot ppu) dot)
            (expect (ppu-read-register ppu 4 t) :to-be #xFF))
      (setf (cl-nes::ppu-dot ppu) 281)
      (expect (ppu-read-register ppu 4 t) :to-be #xFF)))
  (it "copies out-of-range Y bytes to OAM2 without advancing its address"
    (let* ((ppu (make-ppu (make-fixture-cartridge)))
           (oam (ppu-oam ppu))
           (secondary (cl-nes::ppu-secondary-oam ppu)))
      (fill oam #xFF)
      (setf (aref oam #xFC) #x5A)
      (loop for dot from 65 to 192
            do (cl-nes::%ppu-evaluate-sprites! ppu 0 dot))
      (expect (cl-nes::ppu-secondary-oam-count ppu) :to-be 0)
      (expect (aref secondary 0) :to-be #x5A)
      (expect (cl-nes::ppu-oam2-address ppu) :to-be 0)
      (expect (cl-nes::ppu-secondary-oam-data-latch ppu) :to-be #x5A)
      (expect (cl-nes::ppu-sprite-evaluation-secondary-oam-write-p ppu)
              :to-be t)))
  (it "reads OAM2 at its pointer outside sprite fetch"
    (let* ((ppu (make-ppu (make-fixture-cartridge)))
           (secondary (cl-nes::ppu-secondary-oam ppu)))
      (setf (ppu-mask ppu) #x10
            (cl-nes::ppu-scanline ppu) 0
            (cl-nes::ppu-dot ppu) 324
            (cl-nes::ppu-oam2-address ppu) #x18
            (aref secondary #x18) #x06)
      (expect (ppu-read-register ppu 4 t) :to-be #x06)
      (expect (cl-nes::ppu-secondary-oam-data-latch ppu) :to-be #x06)))
  (it "resets OAM2 at dot 339 using the previous rendering dot"
    (let ((ppu (make-ppu (make-fixture-cartridge))))
      (setf (cl-nes::ppu-scanline ppu) 196
            (cl-nes::ppu-dot ppu) 337
            (cl-nes::ppu-rendering-mask-valid-p ppu) t
            (cl-nes::ppu-rendering-mask ppu) #x1E
            (cl-nes::ppu-rendering-mask-pending ppu) 0
            (cl-nes::ppu-rendering-mask-delay ppu) 2
            (cl-nes::ppu-oam2-address ppu) #x1F
            (cl-nes::ppu-oam2-increment-suppressed-p ppu) t)
      (ppu-tick! ppu 2)
      (expect (cl-nes::ppu-dot ppu) :to-be 339)
      (expect (cl-nes::ppu-oam2-address ppu) :to-be 0)
      (expect (cl-nes::ppu-oam2-increment-suppressed-p ppu) :to-be nil)
      (setf (cl-nes::ppu-dot ppu) 337
            (cl-nes::ppu-rendering-mask ppu) 0
            (cl-nes::ppu-rendering-mask-pending ppu) 0
            (cl-nes::ppu-rendering-mask-delay ppu) 0
            (cl-nes::ppu-oam2-address ppu) #x1F
            (cl-nes::ppu-oam2-increment-suppressed-p ppu) t)
      (ppu-tick! ppu 2)
      (expect (cl-nes::ppu-dot ppu) :to-be 339)
      (expect (cl-nes::ppu-oam2-address ppu) :to-be #x1F)
      (expect (cl-nes::ppu-oam2-increment-suppressed-p ppu) :to-be t)
      (setf (cl-nes::ppu-scanline ppu) 241
            (cl-nes::ppu-dot ppu) 337
            (cl-nes::ppu-oam2-address ppu) #x1F
            (cl-nes::ppu-oam2-increment-suppressed-p ppu) t)
      (ppu-tick! ppu 2)
      (expect (cl-nes::ppu-dot ppu) :to-be 339)
      (expect (cl-nes::ppu-oam2-address ppu) :to-be #x1F)
      (expect (cl-nes::ppu-oam2-increment-suppressed-p ppu) :to-be t))))
