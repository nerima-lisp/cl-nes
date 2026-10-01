(in-package #:cl-nes/test)

(declaim (notinline cl-nes::%ppu-address-bus!))

(describe "Coverage: PPU background pixel contracts"
  (it "renders shifted background colors and applies palette masking"
    (with-fixture-ppu (ppu (make-fixture-cartridge))
      (setf (ppu-mask ppu) #x02
            (cl-nes::ppu-background-shift-low ppu) #x8000
            (cl-nes::ppu-background-shift-high ppu) 0
            (cl-nes::ppu-fine-x ppu) 0
            (cl-nes::ppu-dot ppu) 9)
      (ppu-write-vram! ppu #x3F01 #x2B)
      (multiple-value-bind (color present)
          (cl-nes::%ppu-background-pixel-at-dot ppu)
        (expect color :to-be #x2B)
        (expect present :to-be t))
      (setf (ppu-mask ppu) #x01)
      (ppu-write-vram! ppu #x3F00 #x2B)
      (multiple-value-bind (color present)
          (cl-nes::%ppu-background-pixel-at-dot ppu)
        (declare (ignore present))
        (expect color :to-be #x2B))))

  (it "covers background pixel visibility gates"
    (with-fixture-ppu (background-ppu (make-fixture-cartridge))
      (ppu-write-register! background-ppu 1 0)
      (multiple-value-bind (color present)
          (cl-nes::%background-pixel background-ppu 0 0)
        (expect color :to-be 0)
        (expect present :to-be nil))
      (ppu-write-register! background-ppu 1 #x02)
      (multiple-value-bind (color present)
          (cl-nes::%background-pixel background-ppu 0 0)
        (expect color :to-be 0)
        (expect present :to-be nil))
      (ppu-write-register! background-ppu 1 #x06)
      (multiple-value-bind (color present)
          (cl-nes::%background-pixel background-ppu 0 0)
        (expect color :to-be 0)
        (expect present :to-be nil)))))
