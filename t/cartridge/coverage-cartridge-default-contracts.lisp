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
      (expect (cartridge-chr-writable-p cartridge) :to-be t)
      (expect (cartridge-mapper4-variant cartridge) :to-be :mmc3)
      (expect (cartridge-mapper4-variant loaded) :to-be :mmc3)
      (expect (cartridge-chr-writable-p loaded) :to-be t)
      (expect (length (cartridge-chr-rom loaded)) :to-be #x2000)))

  (it "selects MMC4 variants and disables legacy bus conflicts for submappers"
    (let ((mmc4 (load-cartridge
                 (make-ines-image :prg-banks 2
                                  :flags6 #x40
                                  :flags7 #x08
                                  :byte8 #x10)
                 :mapper4-variant :mmc3-alt))
          (mapper2 (load-cartridge
                    (make-ines-image :prg-banks 2
                                     :flags6 #x20
                                     :flags7 #x08
                                     :byte8 #x10))))
      (expect (cartridge-mapper mmc4) :to-be 4)
      (expect (cartridge-submapper mmc4) :to-be 1)
      (expect (cartridge-mapper4-variant mmc4) :to-be :mmc3-alt)
      (expect (cartridge-mapper mapper2) :to-be 2)
      (expect (cartridge-submapper mapper2) :to-be 1)
      (expect (cl-nes::cartridge-bus-conflict-p mapper2) :to-be nil))))
