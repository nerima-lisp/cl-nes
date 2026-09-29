(in-package #:cl-nes/test)

(describe "PPU timing transitions"
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
