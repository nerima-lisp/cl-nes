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
      (expect (cl-nes::%ppu-a12-high-p ppu) :to-be nil))))
