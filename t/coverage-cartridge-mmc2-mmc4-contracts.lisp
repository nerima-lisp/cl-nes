(in-package #:cl-nes/test)

(describe "Coverage: MMC2 and MMC4 cartridge contracts"
  (it "maps PRG banks, CHR latches, and mirroring"
    (let ((mmc2 (make-patterned-cartridge
                 :mapper 9 :prg-banks 16 :chr-banks 64))
          (mmc4 (make-patterned-cartridge
                 :mapper 10 :prg-banks 8 :chr-banks 64)))
      (cartridge-write-prg! mmc2 #xA000 2)
      (expect (cartridge-read-prg mmc2 #x8000) :to-be 2)
      (expect (cartridge-read-prg mmc2 #xA000) :to-be 13)
      (cartridge-write-prg! mmc2 #xB000 5)
      (cartridge-write-prg! mmc2 #xC000 9)
      (cartridge-write-prg! mmc2 #xD000 6)
      (cartridge-write-prg! mmc2 #xE000 10)
      (expect (cartridge-read-chr mmc2 0) :to-be 20)
      (cartridge-read-chr mmc2 #x0FE8)
      (expect (cartridge-read-chr mmc2 0) :to-be 36)
      (expect (cartridge-read-chr mmc2 #x1FD8) :to-be 27)
      (expect (cartridge-read-chr mmc2 #x1000) :to-be 24)
      (cartridge-read-chr mmc2 #x1FE8)
      (expect (cartridge-read-chr mmc2 #x1000) :to-be 40)
      (cartridge-write-prg! mmc2 #xF000 1)
      (expect (cartridge-mirroring mmc2) :to-be :horizontal)
      (cartridge-write-prg! mmc2 #xF000 0)
      (expect (cartridge-mirroring mmc2) :to-be :vertical)
      (cartridge-write-prg! mmc4 #xA000 2)
      (expect (cartridge-read-prg mmc4 #x8000) :to-be 4)
      (expect (cartridge-read-prg mmc4 #xC000) :to-be 6))))
