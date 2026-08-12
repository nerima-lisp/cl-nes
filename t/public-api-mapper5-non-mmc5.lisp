(in-package #:cl-nes/test)

(describe "MMC5 mapper"
  (describe "non-MMC5 cartridges"
    (it "ignores MMC5 expansion operations for other mappers"
      (with-patterned-cartridge (cartridge
                                 :mapper 0
                                 :prg-banks 2
                                 :chr-banks 8)
        (expect (cl-nes::cartridge-write-expansion! cartridge #x5C00 #x42)
                :to-be #x42)
        (expect (cl-nes::cartridge-read-expansion cartridge #x5C00)
                :to-be nil)
        (multiple-value-bind (source within)
            (cl-nes::cartridge-mmc5-nametable-location cartridge #x2000)
          (expect source :to-be nil)
          (expect within :to-be nil))))))
