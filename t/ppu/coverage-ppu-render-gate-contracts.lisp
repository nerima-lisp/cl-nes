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
      (setf (ppu-control ppu) #x10)
      (ppu-write-register! ppu 6 #x10)
      (ppu-write-register! ppu 6 #x00)
      (expect (cl-nes::ppu-address-bus ppu) :to-be #x1000))))
