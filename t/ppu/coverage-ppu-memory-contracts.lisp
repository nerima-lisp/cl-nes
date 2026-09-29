(in-package #:cl-nes/test)

(describe "Coverage: PPU memory contracts"
  (it "switches nametable storage and distinguishes buffered palette reads"
    (let ((ppu (make-ppu)))
      (with-patterned-cartridges ((four :mapper 0 :prg-banks 2 :chr-banks 8 :four-screen-p t)
                                  (normal :mapper 0 :prg-banks 2 :chr-banks 8))
        (ppu-load-cartridge! ppu four)
        (expect (length (cl-nes::ppu-nametable ppu)) :to-be #x1000)
        (ppu-load-cartridge! ppu four)
        (expect (length (cl-nes::ppu-nametable ppu)) :to-be #x1000)
        (ppu-load-cartridge! ppu normal)
        (expect (length (cl-nes::ppu-nametable ppu)) :to-be #x800)
        (ppu-load-cartridge! ppu normal)
        (expect (length (cl-nes::ppu-nametable ppu)) :to-be #x800)
        (ppu-write-vram! ppu #x2000 #xA5)
        (expect (ppu-read-vram ppu #x3000) :to-be #xA5)
        (ppu-write-vram! ppu #x3F00 #x3C)
        (ppu-write-register! ppu 6 #x3F)
        (ppu-write-register! ppu 6 0)
        (expect (ppu-read-register ppu 7) :to-be #x3C)
        (setf (ppu-status ppu) #x80
              (ppu-control ppu) 0
              (ppu-nmi-pending-p ppu) nil
              (cl-nes::ppu-nmi-delay-p ppu) nil)
        (ppu-write-register! ppu 0 #x80)
        (expect (ppu-nmi-pending-p ppu) :to-be t)
        (expect (ppu-take-nmi! ppu) :to-be nil)
        (ppu-tick! ppu 3)
        (expect (ppu-take-nmi! ppu) :to-be t)
        (setf (ppu-nmi-pending-p ppu) t
              (cl-nes::ppu-nmi-delay-p ppu) 3)
        (cl-nes::%request-nmi! ppu)
        (setf (ppu-oam-address ppu) #x12
              (aref (ppu-oam ppu) #x12) #xA6)
        (expect (ppu-read-register ppu 4) :to-be #xA6)
        (expect (ppu-read-register ppu 1) :to-be 0)
        (setf (cl-nes::ppu-scanline ppu) 241
              (cl-nes::ppu-dot ppu) 0)
        (ppu-read-register ppu 2)
        (expect (ppu-nmi-pending-p ppu) :to-be nil)
        (expect (cl-nes::ppu-nmi-delay-p ppu) :to-be nil)))))
