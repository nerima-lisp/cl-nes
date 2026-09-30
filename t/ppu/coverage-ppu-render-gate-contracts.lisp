(in-package #:cl-nes/test)

(describe "Coverage: PPU render gates"
  (it "covers rendering scanline gates and pattern fetch phases"
    (with-fixture-ppu (ppu (make-fixture-cartridge))
      (setf (ppu-mask ppu) 0
            (cl-nes::ppu-scanline ppu) 0)
      (expect (cl-nes::%ppu-rendering-scanline-p ppu) :to-be nil)
      (setf (ppu-mask ppu) #x08)
      (expect (cl-nes::%ppu-rendering-scanline-p ppu) :to-be t)
      (setf (cl-nes::ppu-scanline ppu) 240)
      (expect (cl-nes::%ppu-rendering-scanline-p ppu) :to-be nil)
      (setf (cl-nes::ppu-scanline ppu) 261)
      (expect (cl-nes::%ppu-rendering-scanline-p ppu) :to-be t)
      (setf (ppu-control ppu) 0
            (cl-nes::ppu-dot ppu) 10)
      (expect (cl-nes::%ppu-a12-high-p ppu) :to-be nil)
      (setf (ppu-control ppu) #x10)
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
      (cl-nes::%ppu-clock-render-a12! (make-ppu) t))))
