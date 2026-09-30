(in-package #:cl-nes/test)

(describe "MMC3 banking contracts"
  (it-each ((0 2 3 6 7)
            (#x40 6 3 2 7))
      "maps PRG slots with bank-select bit ~X"
      (bank-select slot-0 slot-1 slot-2 slot-3)
    (with-mmc3-cartridge (cartridge)
      (seed-mmc3-prg-registers! cartridge
        (6 2)
        (7 3))
      (cartridge-write-prg! cartridge #x8000 bank-select)
      (expect-mmc3-prg-layout cartridge
                              (list slot-0 slot-1 slot-2 slot-3))))
  (it-each ((0 2 3 4 5 5 6 7 1)
            (#x80 5 6 7 1 2 3 4 5))
      "maps CHR slots with bank-select bit ~X"
      (bank-select slot-0 slot-1 slot-2 slot-3 slot-4 slot-5 slot-6 slot-7)
    (with-mmc3-cartridge (cartridge)
      (seed-mmc3-prg-registers! cartridge
        (0 2)
        (1 4)
        (2 5)
        (3 6)
        (4 7)
        (5 1))
      (cartridge-write-prg! cartridge #x8000 bank-select)
      (expect-mmc3-chr-layout cartridge
                              (list slot-0 slot-1 slot-2 slot-3
                                    slot-4 slot-5 slot-6 slot-7)))))
