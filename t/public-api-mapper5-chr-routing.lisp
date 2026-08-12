(in-package #:cl-nes/test)

(describe "MMC5 mapper"
  (describe "CHR and nametable routing"
    (define-mmc5-chr-slot-spec
        "maps sprite and background CHR slots in mode ~D"
        ((0 (8 9 10 11 12 13 14 15) (0 1 2 3 4 5 6 7))
         (1 (4 5 6 7 8 9 10 11) (0 1 2 3 0 1 2 3))
         (2 (0 1 2 3 4 5 6 7) (8 9 10 11 10 11 10 11))
         (3 (0 1 2 3 4 5 6 7) (8 9 10 11 8 9 10 11))))
    (it "maps MMC5 nametable sources and fill values"
      (with-mmc5-cartridge (cartridge)
        (write-expansion-registers cartridge
          (#x5105 #xE4))
        (expect-mmc5-nametable-location cartridge #x2012 :ciram-0 #x12)
        (expect-mmc5-nametable-location cartridge #x2412 :ciram-1 #x12)
        (expect-mmc5-nametable-location cartridge #x2812 :exram #x12)
        (expect-mmc5-nametable-location cartridge #x2C12 :fill #x12)
        (write-expansion-registers cartridge
          (#x5106 #xAA)
          (#x5107 2))
        (expect (cl-nes::cartridge-mmc5-fill-value cartridge #x0012)
                :to-be #xAA)
        (expect (cl-nes::cartridge-mmc5-fill-value cartridge #x03C0)
                :to-be #xAA)))))
