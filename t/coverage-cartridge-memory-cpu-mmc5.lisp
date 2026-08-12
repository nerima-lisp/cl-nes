(in-package #:cl-nes/test)

(describe "Coverage: cartridge memory and mapper contracts"
  (it "covers cartridge CPU helper edge cases and MMC5 fill writes"
    (let ((mapper-2 (make-patterned-cartridge
                     :mapper 2 :prg-banks 8 :chr-banks 8))
          (nrom-368 (make-patterned-cartridge
                     :mapper 0 :prg-banks 6 :chr-banks 8))
          (nametable (make-array #x800 :initial-element #x11)))
      (with-mmc5-cartridge (mmc5)
        (expect (cl-nes::cartridge-cpu-read nil #x8000) :to-be nil)
        (expect (cl-nes::cartridge-cpu-write! nil #x8000 #x5A) :to-be #x5A)
        (expect (cl-nes::cartridge-cpu-read mapper-2 #x4000) :to-be nil)
        (expect (cl-nes::cartridge-cpu-write! mapper-2 #x4000 #x66) :to-be #x66)
        (expect (cl-nes::cartridge-cpu-read nrom-368 #x47FF) :to-be nil)
        (expect (cl-nes::cartridge-cpu-read nrom-368 #x4800) :to-be 0)
        (cartridge-write-prg! mapper-2 #x8000 3)
        (expect (cl-nes::cartridge-cpu-read mapper-2 #x8000) :to-be 0)
        (cl-nes::cartridge-write-expansion! mmc5 #x5105 #xE4)
        (cl-nes::cartridge-write-expansion! mmc5 #x5106 #xAA)
        (expect (cl-nes::cartridge-ppu-write-nametable! mmc5 nametable #x2C12 #x77)
                :to-be #x77)
        (expect (cl-nes::cartridge-ppu-read-nametable mmc5 nametable #x2C12)
                :to-be #xAA)
        (expect (aref nametable #x12) :to-be #x11)
        (expect (aref nametable (+ #x400 #x12)) :to-be #x11)))))
