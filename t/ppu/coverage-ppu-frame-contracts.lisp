(in-package #:cl-nes/test)

(describe "Coverage: PPU frame contracts"
  (it "covers the even-frame wrap"
    (with-fixture-ppu (ppu)
      (setf (cl-nes::ppu-scanline ppu) 261
            (cl-nes::ppu-dot ppu) 340
            (cl-nes::ppu-odd-frame-p ppu) nil)
      (ppu-tick! ppu)
      (expect (cl-nes::ppu-scanline ppu) :to-be 0)
      (expect (cl-nes::ppu-dot ppu) :to-be 0)
      (expect (cl-nes::ppu-odd-frame-p ppu) :to-be t))))
