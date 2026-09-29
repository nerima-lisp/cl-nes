(in-package #:cl-nes/test)

(describe "Coverage: PPU render runtime paths"
  (it "renders enabled backgrounds and sprites"
    (let ((cartridge (make-fixture-cartridge)))
      (with-fixture-ppu (ppu cartridge)
        (let ((oam (cl-nes::ppu-oam ppu))
              (framebuffer (ppu-framebuffer ppu)))
          (fill oam #xFF)
          (setf (aref oam 0) 0
                (aref oam 1) 0
                (aref oam 2) #x20
                (aref oam 3) 8)
          (ppu-write-register! ppu 1 #x0E)
          (ppu-write-vram! ppu #x0000 #x80)
          (ppu-write-vram! ppu #x0001 #x80)
          (ppu-write-vram! ppu #x2000 0)
          (ppu-write-vram! ppu #x3F01 #x21)
          (ppu-write-vram! ppu #x3F11 #x22)
          (let ((background-opaque (cl-nes::%render-background! ppu)))
            (expect (aref framebuffer 0) :to-be #x21)
            (expect (aref background-opaque 0) :to-be 1)
            (let ((occupied
                    (make-array (* cl-nes::+ppu-width+ cl-nes::+ppu-height+)
                                :element-type 'bit
                                :initial-element 0)))
              (cl-nes::%draw-sprite-pixel!
               ppu 0 8 1 background-opaque occupied)
              (expect (aref framebuffer (+ 8 cl-nes::+ppu-width+))
                      :to-be #x21)
              (expect (aref occupied (+ 8 cl-nes::+ppu-width+)) :to-be 1)
              (expect (logand (ppu-status ppu) #x40) :to-be #x40))
            (cl-nes::%render-sprites! ppu background-opaque)
            (setf (ppu-status ppu) (logand (ppu-status ppu) #xDF))
            (dotimes (sprite 9)
              (setf (aref oam (* sprite 4)) 0))
            (cl-nes::%render-sprites! ppu background-opaque)
            (expect (logand (ppu-status ppu) #x20) :to-be #x20))))))

  (it "selects background and sprite A12 fetch phases"
    (let ((ppu (make-ppu)))
      (setf (cl-nes::ppu-scanline ppu) 0
            (ppu-control ppu) #x10
            (cl-nes::ppu-dot ppu) 10)
      (expect (cl-nes::%ppu-a12-high-p ppu) :to-be t)
      (setf (cl-nes::ppu-dot ppu) 14)
      (expect (cl-nes::%ppu-a12-high-p ppu) :to-be nil)
      (setf (cl-nes::ppu-dot ppu) 330)
      (expect (cl-nes::%ppu-a12-high-p ppu) :to-be t)
      (setf (cl-nes::ppu-dot ppu) 334)
      (expect (cl-nes::%ppu-a12-high-p ppu) :to-be nil)
      (setf (ppu-control ppu) #x08
            (cl-nes::ppu-dot ppu) 266)
      (expect (cl-nes::%ppu-a12-high-p ppu) :to-be t)
      (setf (cl-nes::ppu-dot ppu) 270)
      (expect (cl-nes::%ppu-a12-high-p ppu) :to-be nil)
      (setf (ppu-control ppu) 0)
      (expect (cl-nes::%ppu-a12-high-p ppu) :to-be nil)))

  (it "covers dot renderer visibility and render-mode branches"
    (with-fixture-ppu (ppu (make-fixture-cartridge))
      (setf (ppu-mask ppu) #x08)
      (expect (cl-nes::%ppu-rendering-enabled-p ppu) :to-be t)
      (setf (ppu-mask ppu) #x10)
      (expect (cl-nes::%ppu-rendering-enabled-p ppu) :to-be t)
      (setf (ppu-mask ppu) 0)
      (expect (cl-nes::%ppu-rendering-enabled-p ppu) :to-be nil)
      (setf (ppu-control ppu) #x10
            (ppu-mask ppu) #x06
            (cl-nes::ppu-vram-address ppu) 0
            (cl-nes::ppu-dot ppu) 1)
      (ppu-write-vram! ppu #x1000 #xFF)
      (ppu-write-vram! ppu #x2000 0)
      (ppu-write-vram! ppu #x3F01 #x21)
      (multiple-value-bind (color solid)
          (cl-nes::%ppu-background-pixel-at-dot ppu)
        (expect color :to-be #x21)
        (expect solid :to-be t))
      (ppu-write-vram! ppu #x1000 0)
      (multiple-value-bind (color solid)
          (cl-nes::%ppu-background-pixel-at-dot ppu)
        (expect color :to-be 0)
        (expect solid :to-be nil))))

  (it "covers pipeline fetch and address-copy variants"
    (with-fixture-ppu (ppu (make-fixture-cartridge))
      (setf (cl-nes::ppu-scanline ppu) 0
            (cl-nes::ppu-dot ppu) 5
            (ppu-control ppu) 0)
      (cl-nes::%ppu-clock-pipeline! ppu)
      (setf (ppu-control ppu) #x10
            (cl-nes::ppu-dot ppu) 7)
      (cl-nes::%ppu-clock-pipeline! ppu)
      (setf (cl-nes::ppu-next-attribute ppu) 3
            (cl-nes::ppu-dot ppu) 0)
      (cl-nes::%ppu-clock-pipeline! ppu)
      (setf (cl-nes::ppu-vram-address ppu) #x03E0
            (cl-nes::ppu-dot ppu) 256)
      (cl-nes::%ppu-clock-pipeline! ppu)
      (setf (cl-nes::ppu-scanline ppu) 261
            (cl-nes::ppu-dot ppu) 280
            (cl-nes::ppu-temporary-address ppu) #x7BE0)
      (cl-nes::%ppu-clock-pipeline! ppu)
      (setf (cl-nes::ppu-scanline ppu) 0
            (cl-nes::ppu-dot ppu) 65
            (ppu-control ppu) #x08)
      (cl-nes::%ppu-clock-pipeline! ppu)
      (setf (cl-nes::ppu-secondary-oam-count ppu) 1
            (cl-nes::ppu-dot ppu) 257)
      (cl-nes::%ppu-clock-pipeline! ppu)))

  (it "covers sprite height and background quadrant branches"
    (with-fixture-ppu (ppu (make-fixture-cartridge))
      (setf (ppu-mask ppu) 0)
      (cl-nes::%render-background! ppu)
      (setf (ppu-mask ppu) #x08
            (ppu-control ppu) #x20)
      (cl-nes::%render-sprites! ppu (cl-nes::ppu-background-opaque ppu))
      (cl-nes::%ppu-evaluate-sprites! ppu 0)
      (setf (ppu-control ppu) #x10
            (ppu-mask ppu) #x06
            (cl-nes::ppu-vram-address ppu) #x0140
            (cl-nes::ppu-dot ppu) 1)
      (ppu-write-vram! ppu #x1000 #xFF)
      (ppu-write-vram! ppu #x2050 0)
      (ppu-write-vram! ppu #x3F01 #x21)
      (multiple-value-bind (color solid)
          (cl-nes::%ppu-background-pixel-at-dot ppu)
        (expect color :to-be #x21)
        (expect solid :to-be t))
      (setf (ppu-mask ppu) #x1C
            (ppu-control ppu) 0
            (ppu-status ppu) #x40
            (cl-nes::ppu-secondary-oam-count ppu) 1
            (aref (cl-nes::ppu-sprite-indexes ppu) 0) 0
            (aref (ppu-oam ppu) 0) 0
            (aref (ppu-oam ppu) 1) 0
            (aref (ppu-oam ppu) 2) 0
            (aref (ppu-oam ppu) 3) 0)
      (ppu-write-vram! ppu #x0000 #x80)
      (ppu-write-vram! ppu #x3F11 #x21)
      (expect (cl-nes::%ppu-sprite-pixel-at-dot ppu 0 1 t)
              :to-be #x21))))
