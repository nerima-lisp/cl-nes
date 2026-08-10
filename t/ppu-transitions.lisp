(in-package #:cl-nes/test)

(defun make-state-transition-cartridge
    (&key (mirroring :horizontal) four-screen-p)
  (make-cartridge
   :prg-rom (make-array #x8000
                        :element-type '(unsigned-byte 8)
                        :initial-element 0)
   :mirroring mirroring
   :four-screen-p four-screen-p
   :chr-writable-p t))

(describe "PPU register and timing transitions"
  (it "resets the scroll latch when status is read"
    (let ((ppu (make-ppu)))
      (ppu-write-register! ppu 5 #x12)
      (setf (ppu-status ppu) #xE0)
      (expect (ppu-read-register ppu 2) :to-be #xE0)
      (expect (ppu-status ppu) :to-be #x60)
      (ppu-write-register! ppu 5 #x34)
      (ppu-write-register! ppu 5 #xA8)
      (expect (cl-nes::ppu-scroll-x ppu) :to-be #x34)
      (expect (cl-nes::ppu-scroll-y ppu) :to-be #xA8)
      (expect (cl-nes::ppu-fine-x ppu) :to-be 4)))
  (it "keeps pattern-table memory open when no cartridge is loaded"
    (let ((ppu (make-ppu)))
      (expect (ppu-read-vram ppu #x1000) :to-be 0)
      (expect (ppu-write-vram! ppu #x1000 #xA5) :to-be #xA5)
      (expect (ppu-read-vram ppu #x1000) :to-be 0)))
  (it "buffers nametable reads and increments VRAM by 32 when selected"
    (let ((ppu (make-ppu)))
      (ppu-write-vram! ppu #x2000 #x55)
      (ppu-write-register! ppu 0 #x04)
      (ppu-write-register! ppu 6 #x20)
      (ppu-write-register! ppu 6 #x00)
      (ppu-write-register! ppu 7 #x11)
      (ppu-write-register! ppu 7 #x22)
      (expect (ppu-read-vram ppu #x2000) :to-be #x11)
      (expect (ppu-read-vram ppu #x2020) :to-be #x22)
      (ppu-write-register! ppu 6 #x20)
      (ppu-write-register! ppu 6 #x00)
      (expect (ppu-read-register ppu 7) :to-be 0)
      (expect (ppu-read-register ppu 7) :to-be #x11)))
  (it "applies horizontal, vertical, and four-screen nametable mapping"
    (let ((horizontal (make-ppu (make-state-transition-cartridge)))
          (vertical (make-ppu
                     (make-state-transition-cartridge
                      :mirroring :vertical)))
          (four-screen (make-ppu
                        (make-state-transition-cartridge
                         :four-screen-p t))))
      (ppu-write-vram! horizontal #x2000 #x11)
      (expect (ppu-read-vram horizontal #x2400) :to-be #x11)
      (ppu-write-vram! vertical #x2000 #x22)
      (ppu-write-vram! vertical #x2400 #x33)
      (expect (ppu-read-vram vertical #x2000) :to-be #x22)
      (expect (ppu-read-vram vertical #x2400) :to-be #x33)
      (ppu-write-vram! four-screen #x2000 #x44)
      (ppu-write-vram! four-screen #x2800 #x55)
      (expect (ppu-read-vram four-screen #x2000) :to-be #x44)
      (expect (ppu-read-vram four-screen #x2800) :to-be #x55)
      (ppu-write-vram! four-screen #x3F10 #x66)
      (expect (ppu-read-vram four-screen #x3F00) :to-be #x66)))
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
  (it "selects background quadrants and 8x16 sprite pattern tables"
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
        (expect present :to-be t))
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
  (it "enters vblank, delays NMI delivery, and starts a new frame"
    (let ((ppu (make-ppu (make-fixture-cartridge))))
      (ppu-write-register! ppu 0 #x80)
      (ppu-tick! ppu (* 241 341))
      (expect (cl-nes::ppu-scanline ppu) :to-be 241)
      (expect (cl-nes::ppu-dot ppu) :to-be 0)
      (ppu-tick! ppu)
      (expect (ppu-frame-ready-p ppu) :to-be t)
      (expect (logand (ppu-status ppu) #x80) :to-be #x80)
      (expect (ppu-nmi-pending-p ppu) :to-be t)
      (expect (ppu-take-nmi! ppu) :to-be nil)
      (expect (ppu-take-nmi! ppu) :to-be t)
      (ppu-tick! ppu (* 20 341))
      (expect (cl-nes::ppu-scanline ppu) :to-be 261)
      (expect (cl-nes::ppu-dot ppu) :to-be 1)
      (expect (ppu-frame-ready-p ppu) :to-be nil)
      (expect (ppu-status ppu) :to-be 0)))
  (it "skips the odd-frame pre-render dot when rendering is enabled"
    (let ((ppu (make-ppu (make-fixture-cartridge))))
      (setf (cl-nes::ppu-scanline ppu) 261
            (cl-nes::ppu-dot ppu) 338
            (cl-nes::ppu-odd-frame-p ppu) t
            (ppu-mask ppu) #x08)
      (ppu-tick! ppu)
      (expect (cl-nes::ppu-dot ppu) :to-be 340)
      (ppu-tick! ppu)
      (expect (cl-nes::ppu-scanline ppu) :to-be 0)
      (expect (cl-nes::ppu-dot ppu) :to-be 0)
      (expect (cl-nes::ppu-odd-frame-p ppu) :to-be nil)))
  (it "does not skip the odd-frame pre-render dot when rendering is disabled"
    (let ((ppu (make-ppu (make-fixture-cartridge))))
      (setf (cl-nes::ppu-scanline ppu) 261
            (cl-nes::ppu-dot ppu) 338
            (cl-nes::ppu-odd-frame-p ppu) t
            (ppu-mask ppu) 0)
      (ppu-tick! ppu)
      (expect (cl-nes::ppu-dot ppu) :to-be 339)
      (ppu-tick! ppu 2)
      (expect (cl-nes::ppu-scanline ppu) :to-be 0)
      (expect (cl-nes::ppu-dot ppu) :to-be 0)
      (expect (cl-nes::ppu-odd-frame-p ppu) :to-be nil))))
