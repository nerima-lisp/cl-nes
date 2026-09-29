(in-package #:cl-nes/test)

(describe "Coverage: mapper contracts"
  (it "resets MMC1 shift state and forces safe mirroring"
    (let ((cartridge (make-contract-cartridge 1)))
      (cartridge-write-prg! cartridge #x8000 #x80)
      (expect (cl-nes::cartridge-mapper-shift cartridge) :to-be #x10)
      (expect (cl-nes::cartridge-mapper-control cartridge) :to-be #x0C)
      (expect (cartridge-mirroring cartridge) :to-be :single-screen-lower)))

  (it "selects MMC1 mirroring and 8 KiB CHR mode"
    (let ((cartridge (make-patterned-cartridge
                      :mapper 1 :prg-banks 4 :chr-banks 32)))
      (write-mmc1-registers! cartridge
        (#x8000 2))
      (expect (cartridge-mirroring cartridge) :to-be :vertical)
      (write-mmc1-registers! cartridge
        (#x8000 3))
      (expect (cartridge-mirroring cartridge) :to-be :horizontal)
      (write-mmc1-registers! cartridge
        (#x8000 0)
        (#xA000 2))
      (expect-mmc1-chr-layout cartridge 16 20)
      (write-mmc1-registers! cartridge
        (#xC000 1))
      (expect (cl-nes::cartridge-mapper-chr-bank-1 cartridge) :to-be 1)))

  (it "updates mapper 28 mirroring and bank registers"
    (let ((cartridge (make-patterned-cartridge
                      :mapper 28 :prg-banks 4 :chr-banks 16)))
      (write-mapper28-registers! cartridge
        (#x80 2))
      (expect (cartridge-mirroring cartridge) :to-be :vertical)
      (write-mapper28-registers! cartridge
        (#x80 3))
      (expect (cartridge-mirroring cartridge) :to-be :horizontal)
      (write-mapper28-registers! cartridge
        (#x80 0)
        (#x00 #x10))
      (expect (cartridge-mirroring cartridge) :to-be :single-screen-upper)
      (write-mapper28-registers! cartridge
        (#x01 0))
      (expect (cartridge-mirroring cartridge) :to-be :single-screen-lower)
      (write-mapper28-registers! cartridge
        (#x80 3)
        (#x00 #x10))
      (expect (cartridge-mirroring cartridge) :to-be :horizontal)
      (write-mapper28-registers! cartridge
        (#x81 #x2A))
      (expect (cl-nes::cartridge-mapper-outer-bank cartridge) :to-be #x2A)))

  (it "does not retrigger MMC3 on a high-to-high A12 sample"
    (let ((cartridge (make-patterned-cartridge
                      :mapper 4 :prg-banks 8 :chr-banks 8)))
      (cartridge-write-prg! cartridge #xC000 0)
      (cartridge-write-prg! cartridge #xE001 0)
      (cl-nes::cartridge-clock-ppu-a12! cartridge nil 24)
      (cl-nes::cartridge-clock-ppu-a12! cartridge t)
      (setf (cl-nes::cartridge-mapper4-irq-pending-p cartridge) nil)
      (cl-nes::cartridge-clock-ppu-a12! cartridge t)
      (expect (cl-nes::cartridge-irq-pending-p cartridge) :to-be nil))))
