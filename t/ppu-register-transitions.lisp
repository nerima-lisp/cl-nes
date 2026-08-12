(in-package #:cl-nes/test)

(describe "PPU register transitions"
  (it "resets the scroll latch when status is read"
    (with-ppu (ppu)
      (write-ppu-registers ppu
        (5 #x12))
      (setf (ppu-status ppu) #xE0)
      (expect (ppu-read-register ppu 2) :to-be #xE0)
      (expect (ppu-status ppu) :to-be #x60)
      (write-ppu-registers ppu
        (5 #x34)
        (5 #xA8))
      (expect (cl-nes::ppu-scroll-x ppu) :to-be #x34)
      (expect (cl-nes::ppu-scroll-y ppu) :to-be #xA8)
      (expect (cl-nes::ppu-fine-x ppu) :to-be 4)))
  (it "mixes status bits with open bus on CPU-visible status reads"
    (with-ppu (ppu)
      (cl-nes::%ppu-drive-decay! ppu #x1F #x1F)
      (setf (ppu-status ppu) #xA0)
      (expect (ppu-read-register ppu 2 t) :to-be #xBF)
      (expect (ppu-status ppu) :to-be #x20)))
  (it "keeps pattern-table memory open when no cartridge is loaded"
    (with-ppu (ppu)
      (expect (ppu-read-vram ppu #x1000) :to-be 0)
      (expect (ppu-write-vram! ppu #x1000 #xA5) :to-be #xA5)
      (expect (ppu-read-vram ppu #x1000) :to-be 0)))
  (it "buffers nametable reads and increments VRAM by 32 when selected"
    (with-ppu (ppu)
      (write-vram-values ppu
        (#x2000 #x55))
      (write-ppu-registers ppu
        (0 #x04))
      (set-ppu-vram-address ppu #x2000)
      (write-ppu-registers ppu
        (7 #x11)
        (7 #x22))
      (expect-vram-values ppu
                          '((#x2000 #x11)
                            (#x2020 #x22)))
      (set-ppu-vram-address ppu #x2000)
      (expect (ppu-read-register ppu 7) :to-be 0)
      (expect (ppu-read-register ppu 7) :to-be #x11))))
