(in-package #:cl-nes/test)

(describe "Coverage: cartridge discrete banking contracts"
  (it "covers the discrete banked mapper windows"
    (with-patterned-cartridges ((mapper-2 :mapper 2 :prg-banks 8 :chr-banks 8)
                                (mapper-3 :mapper 3 :prg-banks 4 :chr-banks 16)
                                (mapper-7 :mapper 7 :prg-banks 8 :chr-banks 8)
                                (mapper-11 :mapper 11 :prg-banks 8 :chr-banks 16)
                                (mapper-34 :mapper 34 :prg-banks 8 :chr-banks 8)
                                (nrom-368 :mapper 0 :prg-banks 6 :chr-banks 8))
      (cartridge-write-prg! mapper-2 #x8000 2)
      (expect (cartridge-read-prg mapper-2 #x8000) :to-be 4)
      (expect (cartridge-read-prg mapper-2 #xC000) :to-be 6)
      (cartridge-write-prg! mapper-3 #x8000 1)
      (expect (cartridge-read-chr mapper-3 0) :to-be 8)
      (cartridge-write-prg! mapper-7 #x8000 #x11)
      (expect (cartridge-read-prg mapper-7 #x8000) :to-be 4)
      (expect (cartridge-mirroring mapper-7) :to-be :single-screen-upper)
      (cartridge-write-prg! mapper-11 #x8000 #x11)
      (expect (cartridge-read-prg mapper-11 #x8000) :to-be 4)
      (expect (cartridge-read-chr mapper-11 0) :to-be 8)
      (cartridge-write-prg! mapper-34 #x8000 1)
      (expect (cartridge-read-prg mapper-34 #x8000) :to-be 4)
      (expect (cartridge-read-prg nrom-368 #x4800) :to-be 0)
      (expect (cartridge-read-prg nrom-368 #x8000) :to-be 2)
      (expect (cartridge-read-prg nrom-368 #xFFFF) :to-be 5)))

  (it "covers mapper 66, 71, and 87 discrete banking"
    (with-patterned-cartridges ((mapper-66 :mapper 66 :prg-banks 16 :chr-banks 32)
                                (mapper-71 :mapper 71 :prg-banks 8 :chr-banks 8)
                                (mapper-87 :mapper 87 :prg-banks 4 :chr-banks 16
                                            :prg-ram-size 0))
      (cartridge-write-prg! mapper-66 #x8000 #x13)
      (expect (cartridge-read-prg mapper-66 #x8000) :to-be 4)
      (expect (cartridge-read-chr mapper-66 0) :to-be 24)
      (cartridge-write-prg! mapper-71 #x8000 2)
      (expect (cartridge-read-prg mapper-71 #x8000) :to-be 4)
      (expect (cartridge-read-prg mapper-71 #xC000) :to-be 6)
      (cartridge-write-prg-ram! mapper-87 #x6000 1)
      (expect (cartridge-read-chr mapper-87 0) :to-be 8)
      (expect (cartridge-read-prg-ram mapper-87 #x6000) :to-be nil)))

  (it "maps mapper 79 CPU writes to patterned PRG and CHR banks"
    (let ((cartridge (make-patterned-cartridge :mapper 79
                                               :prg-banks 8
                                               :chr-banks 64)))
      (expect (cartridge-write-prg! cartridge #x4100 #x11)
              :to-be #x11)
      (expect (cartridge-read-prg cartridge #x8000) :to-be 4)
      (expect (cartridge-read-chr cartridge 0) :to-be 0)
      (expect (cl-nes::cartridge-prg-bank cartridge) :to-be 1)
      (expect (cl-nes::cartridge-chr-bank cartridge) :to-be 1)
      (expect (cartridge-write-prg! cartridge #x4101 #x22)
              :to-be #x22)
      (expect (cl-nes::cartridge-prg-bank cartridge) :to-be 1)))

  (it "applies mapper bus conflicts before bank selection"
    (let ((cartridge (make-patterned-cartridge :mapper 2
                                               :prg-banks 8
                                               :chr-banks 8)))
      (cl-nes::set-cartridge-bus-conflict-p! cartridge t)
      (expect (cartridge-write-prg! cartridge #x8000 #xFF) :to-be #xFF)
      (expect (cl-nes::cartridge-prg-bank cartridge) :to-be 0)
      (expect (cartridge-read-prg cartridge #x8000) :to-be 0))))
