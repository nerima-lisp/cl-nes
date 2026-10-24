(in-package #:cl-nes/test)

(describe "Mapper 113 contracts"
  (it "switches the complete 32 KiB PRG and 8 KiB CHR windows"
    (let ((cartridge (make-patterned-cartridge :mapper 113
                                               :prg-banks 16
                                               :chr-banks 128)))
      (cl-nes::cartridge-cpu-write! cartridge #x4100 #x5D)
      (expect (cartridge-read-prg cartridge #x8000) :to-be 12)
      (expect (cartridge-read-prg cartridge #xC000) :to-be 14)
      (expect (cartridge-read-prg cartridge #xFFFF) :to-be 15)
      (expect (cartridge-read-chr cartridge 0) :to-be 104)
      (expect (cartridge-read-chr cartridge #x1FFF) :to-be 111)
      (expect (length (cartridge-prg-ram cartridge)) :to-be 0)))

  (it "accepts decoded register aliases and ignores addresses outside the decode"
    (let ((cartridge (make-patterned-cartridge :mapper 113
                                               :prg-banks 16
                                               :chr-banks 8)))
      (cl-nes::cartridge-cpu-write! cartridge #x4100 #x08)
      (cl-nes::cartridge-cpu-write! cartridge #x41FF #x10)
      (cl-nes::cartridge-cpu-write! cartridge #x4300 #x18)
      (cl-nes::cartridge-cpu-write! cartridge #x5F00 #x18)
      (cl-nes::cartridge-cpu-write! cartridge #x4200 #x00)
      (cl-nes::cartridge-cpu-write! cartridge #x5E00 #x00)
      (expect (cl-nes::cartridge-prg-bank cartridge) :to-be 3)))

  (it "selects horizontal and vertical nametable mirroring"
    (let ((cartridge (make-patterned-cartridge :mapper 113
                                               :prg-banks 8
                                               :chr-banks 8)))
      (cl-nes::cartridge-cpu-write! cartridge #x4100 #x00)
      (expect (cartridge-mirroring cartridge) :to-be :horizontal)
      (cl-nes::cartridge-cpu-write! cartridge #x4100 #x80)
      (expect (cartridge-mirroring cartridge) :to-be :vertical)))

  (it "resets generic bank fields and restores header mirroring"
    (let ((cartridge (make-cartridge
                      :mapper 113
                      :prg-rom (make-banked-storage 16 cl-nes::+prg-bank-8k-size+)
                      :chr-rom (make-banked-storage 128 cl-nes::+chr-bank-1k-size+)
                      :mirroring :vertical)))
      (cl-nes::cartridge-cpu-write! cartridge #x4100 #x5D)
      (expect (cartridge-read-prg cartridge #x8000) :to-be 12)
      (expect (cartridge-read-chr cartridge 0) :to-be 104)
      (expect (cartridge-mirroring cartridge) :to-be :horizontal)
      (cartridge-reset! cartridge)
      (expect (cl-nes::cartridge-prg-bank cartridge) :to-be 0)
      (expect (cl-nes::cartridge-chr-bank cartridge) :to-be 0)
      (expect (cartridge-read-prg cartridge #x8000) :to-be 0)
      (expect (cartridge-read-chr cartridge 0) :to-be 0)
      (expect (cartridge-mirroring cartridge) :to-be :vertical))))
