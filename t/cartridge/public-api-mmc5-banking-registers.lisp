(in-package #:cl-nes/test)

(describe "MMC5 mapper banking register surface"
  (it "tracks PRG mode and bank registers through CPU writes"
    (with-mmc5-cartridge (cart)
      (expect (cl-nes::cartridge-mapper5-prg-mode cart) :to-be 3)
      (expect (aref (cl-nes::cartridge-mapper5-prg-banks cart) 0) :to-be 0)
      (expect (aref (cl-nes::cartridge-mapper5-prg-banks cart) 3) :to-be 0)

      (write-mmc5-registers! cart
        (#x5100 2)
        (#x5113 #x85)
        (#x5117 #x9f))

      (expect (cl-nes::cartridge-mapper5-prg-mode cart) :to-be 2)
      (expect (aref (cl-nes::cartridge-mapper5-prg-banks cart) 3) :to-be #x85)
      (expect (aref (cl-nes::cartridge-mapper5-prg-banks cart) 7) :to-be #x9f)))

  (it "tracks CHR mode and bank registers through CPU writes"
    (with-mmc5-cartridge (cart)
      (expect (cl-nes::cartridge-mapper5-chr-mode cart) :to-be 3)
      (expect (aref (cl-nes::cartridge-mapper5-chr-banks cart) 0) :to-be 0)
      (expect (aref (cl-nes::cartridge-mapper5-chr-banks cart) 11) :to-be 0)

      (write-mmc5-registers! cart
        (#x5101 1)
        (#x5120 #x12)
        (#x512b #x34))

      (expect (cl-nes::cartridge-mapper5-chr-mode cart) :to-be 1)
      (expect (aref (cl-nes::cartridge-mapper5-chr-banks cart) 0) :to-be #x12)
      (expect (aref (cl-nes::cartridge-mapper5-chr-banks cart) 11) :to-be #x34))))
