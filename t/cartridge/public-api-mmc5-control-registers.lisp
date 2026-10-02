(in-package #:cl-nes/test)

(describe "MMC5 mapper control register surface"
  (it "stores nametable mapping, fill mode, and RAM protection flags"
    (with-mmc5-cartridge (cart)
      (write-mmc5-registers! cart
        (#x5105 #b11100100)
        (#x5106 #x2a)
        (#x5107 #x03)
        (#x5102 #x02)
        (#x5103 #x01))

      (let ((mapping (cl-nes::cartridge-mapper5-nametable-mapping cart)))
        (expect (ldb (byte 2 0) mapping) :to-be 0)
        (expect (ldb (byte 2 2) mapping) :to-be 1)
        (expect (ldb (byte 2 4) mapping) :to-be 2)
        (expect (ldb (byte 2 6) mapping) :to-be 3))
      (expect (cl-nes::cartridge-mapper5-fill-tile cart) :to-be #x2a)
      (expect (cl-nes::cartridge-mapper5-fill-attribute cart) :to-be #x03)
      (expect (cl-nes::%mapper5-prg-ram-writable-p cart) :to-be-truthy)))

  (it "captures EXRAM mode, scanline target, and IRQ enable state"
    (with-mmc5-cartridge (cart)
      (write-mmc5-registers! cart
        (#x5104 1)
        (#x5202 #x12)
        (#x5203 37)
        (#x5204 #x80))

      (expect (cl-nes::cartridge-mapper5-exram-mode cart) :to-be 1)
      (let ((state (cl-nes::cartridge-mapper5-state cart)))
        (expect (cl-nes::cartridge-mapper5-state-split-bank state)
                :to-be #x12)
        (expect (cl-nes::cartridge-mapper5-state-irq-scanline state)
                :to-be 37)
        (expect (cl-nes::cartridge-mapper5-state-irq-enabled-p state)
                :to-be-truthy))))

  (it "updates multiplier operands and exposes the computed product"
    (with-mmc5-cartridge (cart)
      (write-mmc5-registers! cart
        (#x5205 13)
        (#x5206 17))

      (expect (cl-nes::cartridge-read-expansion cart #x5205) :to-be #xdd)
      (expect (cl-nes::cartridge-read-expansion cart #x5206) :to-be 0)))

  (it "round-trips expansion register state and returns written values"
    (with-mmc5-cartridge (cart)
      (expect (cl-nes::cartridge-write-expansion! cart #x5100 #x04)
              :to-be #x04)
      (expect (cl-nes::cartridge-write-expansion! cart #x5101 #xff)
              :to-be #xff)
      (expect (cl-nes::cartridge-write-expansion! cart #x5104 #xff)
              :to-be #xff)
      (expect (cl-nes::cartridge-write-expansion! cart #x5107 #xff)
              :to-be #xff)
      (expect (cl-nes::cartridge-mapper5-prg-mode cart) :to-be 0)
      (expect (cl-nes::cartridge-mapper5-chr-mode cart) :to-be 3)
      (expect (cl-nes::cartridge-mapper5-exram-mode cart) :to-be 3)
      (expect (cl-nes::cartridge-mapper5-fill-attribute cart) :to-be 3)

      (expect (cl-nes::cartridge-write-expansion! cart #x5113 #x12)
              :to-be #x12)
      (expect (cl-nes::cartridge-write-expansion! cart #x5117 #x34)
              :to-be #x34)
      (expect (aref (cl-nes::cartridge-mapper5-prg-banks cart) 3)
              :to-be #x12)
      (expect (aref (cl-nes::cartridge-mapper5-prg-banks cart) 7)
              :to-be #x34)

      (expect (cl-nes::cartridge-write-expansion! cart #x5120 #x56)
              :to-be #x56)
      (expect (cl-nes::cartridge-write-expansion! cart #x512b #x78)
              :to-be #x78)
      (expect (aref (cl-nes::cartridge-mapper5-chr-banks cart) 0)
              :to-be #x56)
      (expect (aref (cl-nes::cartridge-mapper5-chr-banks cart) 11)
              :to-be #x78)))

  (it "honors EXRAM mode boundaries and status read side effects"
    (with-mmc5-cartridge (cart)
      (write-mmc5-registers! cart (#x5104 0))
      (expect (cl-nes::cartridge-write-expansion! cart #x5c00 #xa5)
              :to-be #xa5)
      (expect (cl-nes::cartridge-write-expansion! cart #x5fff #x5a)
              :to-be #x5a)
      (expect (cl-nes::cartridge-read-expansion cart #x5c00) :to-be #xa5)
      (expect (cl-nes::cartridge-read-expansion cart #x5fff) :to-be #x5a)
      (write-mmc5-registers! cart (#x5104 3))
      (expect (cl-nes::cartridge-write-expansion! cart #x5c00 #x11)
              :to-be #x11)
      (expect (cl-nes::cartridge-read-expansion cart #x5c00) :to-be nil)

      (write-mmc5-registers! cart (#x5203 12) (#x5204 #x80))
      (cl-nes::cartridge-clock-scanline! cart 12)
      (expect (cl-nes::cartridge-read-expansion cart #x5204) :to-be #xc0)
      (expect (cl-nes::cartridge-read-expansion cart #x5204) :to-be #x40))))
