(in-package #:cl-nes/test)

(describe "Coverage: cartridge MMC1 contracts"
  (it "covers MMC1 PRG modes and CHR banking"
    (let ((cartridge (make-patterned-cartridge
                      :mapper 1 :prg-banks 8 :chr-banks 32)))
      (exercise-mmc1-prg-cases cartridge
        (((#x8000 0)
          (#xE000 3))
         4 6)
        (((#x8000 8))
         0 6)
        (((#x8000 12)
          (#xE000 1))
         2 6))
      (write-mmc1-registers! cartridge
        (#xA000 2)
        (#xC000 3))
      (expect-mmc1-chr-layout cartridge 16 20)
      (write-mmc1-registers! cartridge
        (#x8000 0)
        (#xA000 2))
      (expect (cartridge-read-chr cartridge 0) :to-be 16)
      (cartridge-write-prg! cartridge #x8000 #x80)
      (expect (cl-nes::cartridge-mapper-shift cartridge) :to-be #x10)
      (write-mmc1-registers! cartridge
        (#x8000 1))
      (expect (cartridge-mirroring cartridge) :to-be :single-screen-upper)
      (write-mmc1-registers! cartridge
        (#x8000 #x10)
        (#xA000 1)
        (#xC000 2))
      (expect-mmc1-chr-layout cartridge 4 8))))
