(in-package #:cl-nes/test)

(describe "Coverage: PPU runtime paths"
  (it "renders enabled backgrounds and sprites"
    (with-fixture-ppu (ppu)
      (let ((framebuffer (ppu-framebuffer ppu)))
        (fill (cl-nes::ppu-oam ppu) #xFF)
        (write-oam-values ppu
          (0 0)
          (1 0)
          (2 #x20)
          (3 8))
        (ppu-write-register! ppu 1 #x0E)
        (write-vram-values ppu
          (#x0000 #x80)
          (#x0001 #x80)
          (#x2000 0)
          (#x3F01 #x21)
          (#x3F11 #x22))
        (let ((background-opaque (cl-nes::%render-background! ppu)))
          (expect (aref framebuffer 0) :to-be #x21)
          (expect (aref background-opaque 0) :to-be 1)
          (with-screen-bits (occupied)
            (cl-nes::%draw-sprite-pixel!
             ppu 0 8 1 background-opaque occupied)
            (expect (aref framebuffer (+ 8 cl-nes::+ppu-width+))
                    :to-be #x21)
            (expect (aref occupied (+ 8 cl-nes::+ppu-width+)) :to-be 1)
            (expect (logand (ppu-status ppu) #x40) :to-be #x40))
          (cl-nes::%render-sprites! ppu background-opaque)
          (setf (ppu-status ppu) (logand (ppu-status ppu) #xDF))
          (dotimes (sprite 9)
            (write-oam-values ppu
              ((* sprite 4) 0)))
          (cl-nes::%render-sprites! ppu background-opaque)
          (expect (logand (ppu-status ppu) #x20) :to-be #x20)))))

  (it "renders 8x16 sprites from the low pattern table and detects overflow"
    (with-fixture-ppu (ppu)
      (let ((framebuffer (ppu-framebuffer ppu))
            (background-opaque
              (make-array (* cl-nes::+ppu-width+ cl-nes::+ppu-height+)
                          :element-type 'bit
                          :initial-element 0)))
        (fill (cl-nes::ppu-oam ppu) #xFF)
        (ppu-write-register! ppu 0 #x20)
        (ppu-write-register! ppu 1 #x18)
        (write-vram-values ppu
          (#x0000 #x80)
          (#x3F11 #x22))
        (dotimes (sprite 9)
          (write-oam-values ppu
            ((* sprite 4) 0)
            ((1+ (* sprite 4)) 0)
            ((+ 2 (* sprite 4)) 0)
            ((+ 3 (* sprite 4)) (+ 8 sprite))))
        (cl-nes::%render-sprites! ppu background-opaque)
        (expect (aref framebuffer (+ 8 cl-nes::+ppu-width+)) :to-be #x22)
        (expect (logand (ppu-status ppu) #x20) :to-be #x20))))

  (it "expires decay and applies delayed masks"
    (let ((ppu (make-ppu)))
      (cl-nes::%ppu-drive-decay! ppu #xFF)
      (expect (ppu-read-register ppu 0 t) :to-be #xFF)
      (cl-nes::%ppu-clock-decay! ppu cl-nes::+ppu-decay-period+)
      (expect (cl-nes::ppu-decay-value ppu) :to-be 0)
      (ppu-write-register! ppu 3 2)
      (ppu-write-register! ppu 4 #xFF)
      (ppu-write-register! ppu 3 2)
      (expect (ppu-read-register ppu 4 t) :to-be #xE3)
      (setf (ppu-status ppu) #x80)
      (ppu-write-register! ppu 0 #x80)
      (expect (cl-nes::ppu-nmi-pending-p ppu) :to-be t)
      (ppu-write-register! ppu 0 0)
      (expect (cl-nes::ppu-nmi-pending-p ppu) :to-be nil)
      (ppu-write-register! ppu 1 #x08)
      (expect (cl-nes::%ppu-effective-mask ppu) :to-be 0)
      (ppu-tick! ppu)
      (expect (cl-nes::ppu-rendering-mask-delay ppu) :to-be 1)
      (ppu-tick! ppu)
      (expect (cl-nes::%ppu-effective-mask ppu) :to-be #x08)))

  (it "applies a pending rendering mask immediately when the delay is already zero"
    (let ((ppu (make-ppu)))
      (setf (cl-nes::ppu-rendering-mask-valid-p ppu) t
            (cl-nes::ppu-rendering-mask-delay ppu) 0
            (cl-nes::ppu-rendering-mask-pending ppu) #x18)
      (ppu-tick! ppu)
      (expect (cl-nes::%ppu-effective-mask ppu) :to-be #x18)))

  (it "expires only decay bits whose deadlines have passed"
    (let ((ppu (make-ppu)))
      (cl-nes::%ppu-drive-decay! ppu #x01 #x01)
      (cl-nes::%ppu-clock-decay! ppu (floor cl-nes::+ppu-decay-period+ 2))
      (cl-nes::%ppu-drive-decay! ppu #x02 #x02)
      (cl-nes::%ppu-clock-decay! ppu (floor cl-nes::+ppu-decay-period+ 2))
      (expect (cl-nes::ppu-decay-value ppu) :to-be #x02)
      (expect (aref (cl-nes::ppu-decay-deadlines ppu) 0)
              :to-be most-positive-fixnum)
      (expect (aref (cl-nes::ppu-decay-deadlines ppu) 1)
              :not :to-be most-positive-fixnum))))
