(in-package #:cl-nes/test)

(describe "Coverage: cartridge memory and mapper contracts"
  (it "covers the discrete banked mapper windows"
    (let ((mapper-2 (make-patterned-cartridge
                     :mapper 2 :prg-banks 8 :chr-banks 8))
          (mapper-3 (make-patterned-cartridge
                     :mapper 3 :prg-banks 4 :chr-banks 16))
          (mapper-7 (make-patterned-cartridge
                     :mapper 7 :prg-banks 8 :chr-banks 8))
          (mapper-11 (make-patterned-cartridge
                      :mapper 11 :prg-banks 8 :chr-banks 16))
          (mapper-34 (make-patterned-cartridge
                      :mapper 34 :prg-banks 8 :chr-banks 8))
          (nrom-368 (make-patterned-cartridge
                     :mapper 0 :prg-banks 6 :chr-banks 8)))
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
      (expect (cartridge-read-prg nrom-368 #xFFFF) :to-be 5))))
