(in-package #:cl-nes/test)

(describe "Cartridge discrete mapper contracts"
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

  (it "bounds PRG-RAM and CHR memory windows"
    (let ((cartridge (make-patterned-cartridge
                      :mapper 0 :prg-banks 2 :chr-banks 8
                      :prg-ram-size #x2000)))
      (expect (cartridge-read-prg cartridge #x7FFF) :to-be nil)
      (cartridge-write-prg-ram! cartridge #x6000 #x1FF)
      (expect (cartridge-read-prg-ram cartridge #x6000) :to-be #xFF)
      (expect (cartridge-read-prg-ram cartridge #x5FFF) :to-be nil)
      (expect (cartridge-read-prg-ram cartridge #x8000) :to-be nil)
      (expect (cartridge-write-prg-ram! cartridge #x8000 #x42) :to-be #x42))
    (let ((empty (make-patterned-cartridge
                  :mapper 0 :prg-banks 2 :chr-banks 8
                  :prg-ram-size 0)))
      (expect (cartridge-read-prg-ram empty #x6000) :to-be nil)
      (expect (cartridge-write-prg-ram! empty #x6000 #x42) :to-be #x42))
    (let ((read-only (make-patterned-cartridge
                      :mapper 0 :prg-banks 2 :chr-banks 8)))
      (expect (cartridge-write-chr! read-only 0 #xA5) :to-be #xA5)
      (expect (cartridge-read-chr read-only 0) :to-be 0))
    (let ((writable (make-fixture-cartridge)))
      (expect (cartridge-write-chr! writable 0 #x1FF) :to-be #x1FF)
      (expect (cartridge-read-chr writable 0) :to-be #xFF)
      (expect (cartridge-read-chr writable #x2000) :to-be nil)
      (expect (cartridge-write-chr! writable #x2000 #x77) :to-be #x77)))

  (it "routes CPU and PPU memory through cartridge windows"
    (let* ((cartridge (make-patterned-cartridge
                       :mapper 0 :prg-banks 2 :chr-banks 8))
           (ciram (make-array #x800
                             :element-type '(unsigned-byte 8)
                             :initial-element 0)))
      (expect (cl-nes::cartridge-cpu-read nil #x8000) :to-be nil)
      (expect (cl-nes::cartridge-cpu-write! nil #x8000 #xA5) :to-be #xA5)
      (expect (cl-nes::cartridge-cpu-read cartridge #x5000) :to-be nil)
      (expect (cl-nes::cartridge-cpu-read cartridge #x4000) :to-be nil)
      (expect (cl-nes::cartridge-cpu-write! cartridge #x4000 #x5A) :to-be #x5A)
      (expect (cl-nes::cartridge-ppu-write-nametable!
               cartridge ciram #x2000 #xA5)
              :to-be #xA5)
      (expect (cl-nes::cartridge-ppu-read-nametable cartridge ciram #x2400)
              :to-be #xA5)
      (expect (cl-nes::cartridge-ppu-write-nametable!
               nil ciram #x2000 #x5A)
              :to-be #x5A)
      (expect (aref ciram 0) :to-be #x5A))))
