(in-package #:cl-nes/test)

(describe "MMC5 mapper"
  (describe "PRG banking"
    (define-mmc5-prg-slot-spec
        "maps PRG slots in mode ~D"
        ((0 4 5 6 7)
         (1 8 9 12 13)
         (2 2 3 10 14)
         (3 4 5 6 7)))
    (it "maps writable PRG-RAM through CPU address space"
      (with-mmc5-cartridge (cartridge)
        (configure-mmc5-prg-banks cartridge 3)
        (write-expansion-registers cartridge
          (#x5114 0))
        (expect (cartridge-read-prg cartridge #x8000) :to-be 0)
        (cartridge-write-prg! cartridge #x8000 #x5A)
        (expect (aref (cartridge-prg-ram cartridge) 0) :to-be 0)
        (write-expansion-registers cartridge
          (#x5102 2)
          (#x5103 1))
        (expect (cartridge-write-prg! cartridge #x8000 #xA5) :to-be #xA5)
        (expect (aref (cartridge-prg-ram cartridge) 0) :to-be #xA5)
        (expect (cartridge-read-prg cartridge #x8000) :to-be #xA5)
        (write-expansion-registers cartridge
          (#x5114 #x80))
        (expect (cartridge-read-prg cartridge #x8000) :to-be 0)
        (cartridge-write-prg! cartridge #x8000 #x5A)
        (expect (aref (cartridge-prg-ram cartridge) 0) :to-be #xA5)))
    (it "banks and protects PRG-RAM at $6000"
      (with-mmc5-cartridge
          (cartridge :prg-ram-size (* 2 cl-nes::+prg-ram-bank-size+))
        (write-expansion-registers cartridge
          (#x5113 1))
        (expect (cartridge-read-prg-ram cartridge #x6000) :to-be 0)
        (expect (cartridge-write-prg-ram! cartridge #x6000 #xA5)
                :to-be #xA5)
        (expect (aref (cartridge-prg-ram cartridge)
                      cl-nes::+prg-ram-bank-size+)
                :to-be 0)
        (write-expansion-registers cartridge
          (#x5102 2)
          (#x5103 1))
        (expect (cartridge-write-prg-ram! cartridge #x6000 #xA5)
                :to-be #xA5)
        (expect (cartridge-read-prg-ram cartridge #x6000) :to-be #xA5)
        (expect (aref (cartridge-prg-ram cartridge)
                      cl-nes::+prg-ram-bank-size+)
                :to-be #xA5)
        (write-expansion-registers cartridge
          (#x5102 0))
        (cartridge-write-prg-ram! cartridge #x6000 #x5A)
        (expect (cartridge-read-prg-ram cartridge #x6000) :to-be #xA5)))
    (it "leaves an empty PRG-RAM window unavailable"
      (with-mmc5-cartridge (cartridge :prg-ram-size 0)
        (expect (cartridge-read-prg-ram cartridge #x6000) :to-be nil)
        (write-expansion-registers cartridge
          (#x5114 0))
        (expect (cartridge-read-prg cartridge #x8000) :to-be nil)
        (expect (cartridge-write-prg-ram! cartridge #x6000 #xA5)
                :to-be #xA5)))))
