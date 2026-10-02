(in-package #:cl-nes/test)

(describe "Coverage: cartridge PRG-RAM contracts"
  (it "covers PRG-RAM protection and bus cartridge routing"
    (with-patterned-cartridges ((mapper-4 :mapper 4 :prg-banks 8 :chr-banks 8)
                                (mapper-2 :mapper 2 :prg-banks 8 :chr-banks 8))
      (let ((bus (make-bus :cartridge mapper-2)))
        (cartridge-write-prg-ram! mapper-4 #x6000 #xA5)
        (expect (cartridge-read-prg-ram mapper-4 #x6000) :to-be #xA5)
        (setf (cl-nes::cartridge-mapper4-prg-ram-enabled-p mapper-4) nil)
        (expect (cartridge-read-prg-ram mapper-4 #x6000) :to-be nil)
        (cartridge-write-prg-ram! mapper-4 #x6000 #x5A)
        (setf (cl-nes::cartridge-mapper4-prg-ram-enabled-p mapper-4) t
              (cl-nes::cartridge-mapper4-prg-ram-write-protected-p mapper-4) t)
        (cartridge-write-prg-ram! mapper-4 #x6000 #x5A)
        (expect (cartridge-read-prg-ram mapper-4 #x6000) :to-be #xA5)
        (setf (cl-nes::cartridge-mapper4-prg-ram-write-protected-p mapper-4) nil)
        (cartridge-write-prg-ram! mapper-4 #x6000 #x5A)
        (expect (cartridge-read-prg-ram mapper-4 #x6000) :to-be #x5A)
        (setf (cl-nes::cartridge-battery-backed-p mapper-4) nil
              (cl-nes::cartridge-battery-dirty-p mapper-4) nil)
        (cartridge-write-prg-ram! mapper-4 #x6000 #x33)
        (expect (cl-nes::cartridge-battery-dirty-p mapper-4) :to-be nil)
        (setf (cl-nes::cartridge-battery-backed-p mapper-4) t
              (cl-nes::cartridge-battery-dirty-p mapper-4) nil)
        (cartridge-write-prg-ram! mapper-4 #x6000 #x44)
        (expect (cl-nes::cartridge-battery-dirty-p mapper-4) :to-be t)
        (bus-write! bus #x8000 2)
        (expect (cartridge-read-prg (cl-nes::bus-cartridge bus) #x8000) :to-be 4)
        (expect (funcall (cl-nes::apu-memory-reader (bus-apu bus)) #x8000)
                :to-be 4))))

  (it "uses MMC5 PRG bank registers for PRG-RAM accesses"
    (with-mmc5-cartridge (cartridge)
      (write-mmc5-registers! cartridge
        (#x5102 2)
        (#x5103 1)
        (#x5113 1))
      (expect (cartridge-write-prg-ram! cartridge #x6000 #xA5) :to-be #xA5)
      (expect (cartridge-read-prg-ram cartridge #x6000) :to-be #xA5)
      (expect (aref (cartridge-prg-ram cartridge) #x2000) :to-be #xA5))))
