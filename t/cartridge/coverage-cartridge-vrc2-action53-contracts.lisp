(in-package #:cl-nes/test)

(describe "Coverage: cartridge VRC2 and Action 53 contracts"
  (it "covers VRC2 register wiring and Action 53 bank modes"
    (with-patterned-cartridges ((vrc2 :mapper 22 :prg-banks 8 :chr-banks 32)
                                (action-53 :mapper 28 :prg-banks 64 :chr-banks 32))
      (cartridge-write-prg! vrc2 #x8000 3)
      (cartridge-write-prg! vrc2 #xA000 4)
      (expect (cartridge-read-prg vrc2 #x8000) :to-be 3)
      (expect (cartridge-read-prg vrc2 #xA000) :to-be 4)
      (expect (cartridge-read-prg vrc2 #xC000) :to-be 6)
      (expect (cartridge-read-prg vrc2 #xE000) :to-be 7)
      (cartridge-write-prg! vrc2 #x9000 1)
      (expect (cartridge-mirroring vrc2) :to-be :horizontal)
      (cartridge-write-prg! vrc2 #x9001 0)
      (dolist (page '(#xB000 #xC000 #xD000 #xE000))
        (cartridge-write-prg! vrc2 page 1)
        (cartridge-write-prg! vrc2 (1+ page) 2)
        (cartridge-write-prg! vrc2 (+ page 2) 3)
        (cartridge-write-prg! vrc2 (+ page 3) 4))
      (expect (cartridge-read-chr vrc2 0) :to-be 24)
      (expect (cartridge-read-chr vrc2 #x400) :to-be 1)
      (write-mapper28-registers! action-53
        (#x81 1))
      (exercise-mapper28-bank-modes action-53 '(0 4 8 12)
        (#x00 #x10)
        (#x01 #x0E))
      (write-mapper28-registers! action-53
        (#x80 8)
        (#x00 0))
      (expect (cartridge-mirroring action-53) :to-be :single-screen-lower)
      (write-mapper28-registers! action-53
        (#x81 #x3F))
      (expect (cl-nes::cartridge-mapper-outer-bank action-53) :to-be #x3F))))
