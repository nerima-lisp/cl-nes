(in-package #:cl-nes/test)

(describe "Cartridge memory contracts"
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
      (expect (cartridge-write-chr! writable #x2000 #x77) :to-be #x77))))
