(in-package #:cl-nes/test)

(describe "Coverage: cartridge constructor defaults"
  (it "exercises cartridge constructor and loader defaults"
    (let* ((prg (make-array (* 16 1024)
                            :element-type '(unsigned-byte 8)
                            :initial-element 0))
           (cartridge (make-cartridge :prg-rom prg))
           (loaded (load-cartridge (make-ines-image))))
      (expect (cartridge-mapper cartridge) :to-be 0)
      (expect (cartridge-mirroring cartridge) :to-be :horizontal)
      (expect (length (cartridge-prg-ram cartridge)) :to-be #x2000)
      (expect (cartridge-mapper4-variant cartridge) :to-be :mmc3)
      (expect (cartridge-mapper4-variant loaded) :to-be :mmc3))))
