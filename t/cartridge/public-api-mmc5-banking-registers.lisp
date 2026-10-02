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
      (expect (aref (cl-nes::cartridge-mapper5-chr-banks cart) 11) :to-be #x34)))

  (it "writes through a writable mapped PRG-RAM window"
    (with-mmc5-cartridge (cart)
      (write-mmc5-registers! cart
        (#x5100 3)
        (#x5102 2)
        (#x5103 1)
        (#x5114 0))
      (cartridge-write-prg! cart #x8000 #xa5)
      (expect (cartridge-read-prg cart #x8000) :to-be #xa5)))

  (it "enforces PRG-RAM protection while preserving write return values"
    (with-mmc5-cartridge (cart)
      (write-mmc5-registers! cart
        (#x5100 3)
        (#x5114 0)
        (#x5102 2)
        (#x5103 1))
      (expect (cartridge-write-prg! cart #x8000 #x1ff) :to-be #x1ff)
      (expect (cartridge-read-prg cart #x8000) :to-be #xff)
      (write-mmc5-registers! cart (#x5102 0))
      (expect (cartridge-write-prg! cart #x8000 #x5a) :to-be #x5a)
      (expect (cartridge-read-prg cart #x8000) :to-be #xff)

      (write-mmc5-registers! cart
        (#x5100 0)
        (#x5113 #x07)
        (#x5102 2)
        (#x5103 1))
      (expect (cartridge-write-prg-ram! cart #x6000 #x1ab) :to-be #x1ab)
      (expect (cartridge-read-prg-ram cart #x6000) :to-be #xab)
      (expect (cartridge-read-prg-ram cart #x7fff) :to-be 0))))
