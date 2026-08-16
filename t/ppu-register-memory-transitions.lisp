(in-package #:cl-nes/test)

(describe "PPU register memory transitions"
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
      (expect (ppu-read-register ppu 7) :to-be #x11))))
