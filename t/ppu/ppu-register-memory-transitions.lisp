(in-package #:cl-nes/test)

(describe "PPU register memory transitions"
  (it "updates the temporary address and propagates the rendering mask"
    (let ((ppu (make-ppu)))
      (ppu-write-register! ppu 0 #x03)
      (expect (ppu-control ppu) :to-be #x03)
      (expect (cl-nes::ppu-temporary-address ppu) :to-be #x0C00)
      (ppu-write-register! ppu 1 #x18)
      (expect (ppu-mask ppu) :to-be #x18)
      (expect (cl-nes::ppu-rendering-mask ppu) :to-be 0)
      (ppu-tick! ppu)
      (expect (cl-nes::ppu-rendering-mask ppu) :to-be 0)
      (ppu-tick! ppu)
      (expect (cl-nes::ppu-rendering-mask ppu) :to-be #x18)))

  (it "wraps the 15-bit VRAM address and uses palette reads immediately"
    (let ((ppu (make-ppu)))
      (ppu-write-register! ppu 6 #x7F)
      (ppu-write-register! ppu 6 #xFF)
      (expect (cl-nes::ppu-vram-address ppu) :to-be #x3FFF)
      (ppu-write-vram! ppu #x3F00 #x2A)
      (ppu-write-register! ppu 6 #x3F)
      (ppu-write-register! ppu 6 #x00)
      (expect (ppu-read-register ppu 7) :to-be #x2A)
      (expect (cl-nes::ppu-vram-address ppu) :to-be #x3F01)))

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

  (it "cancels a delayed NMI when status is read in the active window"
    (let ((ppu (make-ppu)))
      (setf (ppu-status ppu) #x80
            (cl-nes::ppu-nmi-pending-p ppu) t
            (cl-nes::ppu-nmi-delay-p ppu) 2)
      (expect (ppu-read-register ppu 2) :to-be #x80)
      (expect (cl-nes::ppu-nmi-delay-p ppu) :to-be 0)))

  (it "uses the delayed NMI timing for a CPU control write at vblank"
    (let ((ppu (make-ppu)))
      (setf (ppu-status ppu) #x80
            (cl-nes::ppu-scanline ppu) 241)
      (ppu-write-register! ppu 0 #x80 t)
      (expect (cl-nes::ppu-nmi-delay-p ppu) :to-be 6)
      (ppu-write-register! ppu 0 #x80)
      (ppu-write-register! ppu 0 0)
      (expect (cl-nes::ppu-nmi-pending-p ppu) :to-be nil)))

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

  (it "wraps coarse Y at the final nametable row"
    (let ((ppu (make-ppu)))
      (setf (cl-nes::ppu-vram-address ppu) #x73E0)
      (cl-nes::%ppu-vertical-increment! ppu)
      (expect (cl-nes::ppu-vram-address ppu) :to-be 0))))
