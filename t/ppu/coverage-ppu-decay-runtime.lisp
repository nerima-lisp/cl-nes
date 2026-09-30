(in-package #:cl-nes/test)

(describe "Coverage: PPU decay runtime paths"
  (it "expires decay state fully"
    (let ((ppu (make-ppu)))
      (cl-nes::%ppu-drive-decay! ppu #xFF)
      (expect (ppu-read-register ppu 0 t) :to-be #xFF)
      (cl-nes::%ppu-clock-decay! ppu cl-nes::+ppu-decay-period+)
      (expect (cl-nes::ppu-decay-value ppu) :to-be 0)))

  (it "covers partial decay expiry"
    (let ((ppu (make-ppu)))
      (cl-nes::%ppu-drive-decay! ppu #xA5 #x0F)
      (expect (cl-nes::%ppu-current-decay ppu) :to-be #x05)
      (cl-nes::%ppu-clock-decay! ppu cl-nes::+ppu-decay-period+)
      (expect (cl-nes::%ppu-current-decay ppu) :to-be 0)))

  (it "reads palette data with decay bits and resets the read buffer"
    (let ((ppu (make-ppu)))
      (setf (cl-nes::ppu-vram-address ppu) #x3F00
            (cl-nes::ppu-read-buffer ppu) #x11)
      (ppu-write-vram! ppu #x3F00 #x23)
      (cl-nes::%ppu-drive-decay! ppu #xC0 #xC0)
      (expect (ppu-read-register ppu 7 t) :to-be #xE3)
      (expect (cl-nes::ppu-read-buffer ppu) :to-be 0))))
