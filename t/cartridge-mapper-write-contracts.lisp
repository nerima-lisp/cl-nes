(in-package #:cl-nes/test)

(describe "Cartridge mapper write contracts"
  (it "keeps AxROM bank and mirroring writes explicit"
    (let ((cartridge (make-patterned-cartridge
                      :mapper 7 :prg-banks 4 :chr-banks 8)))
      (cartridge-write-prg! cartridge #x8000 #x1A)
      (expect (cl-nes::cartridge-prg-bank cartridge) :to-be 2)
      (expect (cartridge-mirroring cartridge) :to-be :single-screen-upper)
      (cartridge-write-prg! cartridge #x8000 #x02)
      (expect (cartridge-mirroring cartridge) :to-be :single-screen-lower)))

  (it "maps VRC2 mirroring and split CHR registers"
    (let ((cartridge (make-patterned-cartridge
                      :mapper 22 :prg-banks 8 :chr-banks 8)))
      (cartridge-write-prg! cartridge #x9000 0)
      (expect (cartridge-mirroring cartridge) :to-be :vertical)
      (cartridge-write-prg! cartridge #x9000 1)
      (expect (cartridge-mirroring cartridge) :to-be :horizontal)
      (cartridge-write-prg! cartridge #xB000 #x05)
      (cartridge-write-prg! cartridge #xB002 #x0A)
      (expect (aref (cl-nes::cartridge-mapper-registers cartridge) 0)
              :to-be #xA5)
      (cartridge-write-prg! cartridge #xF000 #xFF)
      (expect (aref (cl-nes::cartridge-mapper-registers cartridge) 0)
              :to-be #xA5)))

  (it "swaps VRC2 low address bits when decoding CHR nibble writes"
    (let ((cartridge (make-patterned-cartridge
                      :mapper 22 :prg-banks 8 :chr-banks 8)))
      (cartridge-write-prg! cartridge #xB001 #x09)
      (cartridge-write-prg! cartridge #xB003 #x04)
      (expect (aref (cl-nes::cartridge-mapper-registers cartridge) 0)
              :to-be 0)
      (expect (aref (cl-nes::cartridge-mapper-registers cartridge) 1)
              :to-be #x49)))

  (it-each ((2 #x7FFF 8 8 0 0)
            (3 #x7FFF 2 8 0 0)
            (7 #x7FFF 8 8 0 :horizontal)
            (11 #x7FFF 8 8 0 0)
            (34 #x7FFF 8 8 0 0))
    "ignores standard PRG register writes outside #x8000-#xFFFF for mapper ~D"
    (mapper address prg-banks chr-banks expected-prg-bank expected-secondary)
    (let ((cartridge
            (make-patterned-cartridge
             :mapper mapper
             :prg-banks prg-banks
             :chr-banks chr-banks)))
      (setf (cartridge-mirroring cartridge) :horizontal)
      (cartridge-write-prg! cartridge address #xFF)
      (expect (cl-nes::cartridge-prg-bank cartridge) :to-be expected-prg-bank)
      (case mapper
        (3
         (expect (cl-nes::cartridge-chr-bank cartridge) :to-be expected-secondary))
        (7
         (expect (cartridge-mirroring cartridge) :to-be expected-secondary))
        (11
         (expect (cl-nes::cartridge-chr-bank cartridge) :to-be expected-secondary)))))

  (it "limits mapper 28 register writes to expansion and PRG ranges"
    (let ((cartridge (make-patterned-cartridge
                      :mapper 28 :prg-banks 8 :chr-banks 8)))
      (cartridge-write-prg! cartridge #x4000 #x81)
      (expect (cl-nes::cartridge-mapper-register-select cartridge) :to-be 0)
      (cartridge-write-prg! cartridge #x5000 #x81)
      (expect (cl-nes::cartridge-mapper-register-select cartridge) :to-be #x81)
      (cartridge-write-prg! cartridge #x6000 #x80)
      (expect (cl-nes::cartridge-mapper-mode cartridge) :to-be #x0F)
      (cartridge-write-prg! cartridge #x8000 #x80)
      (expect (cl-nes::cartridge-mapper-outer-bank cartridge) :to-be 0)))

  (it "ignores MMC5 mapped PRG writes outside #x8000-#xFFFF"
    (with-mmc5-cartridge (cartridge)
      (let ((before (copy-seq (cl-nes::cartridge-mapper5-prg-banks cartridge))))
        (cartridge-write-prg! cartridge #x7FFF #x99)
        (cartridge-write-prg! cartridge #x6000 #x55)
        (expect (coerce (cl-nes::cartridge-mapper5-prg-banks cartridge) 'list)
                :to-equal
                (coerce before 'list))))))
