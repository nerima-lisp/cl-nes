(in-package #:cl-nes/test)

(describe "Cartridge mapper 28 construction contracts"
  (it "uses the mapper 28 CHR default and keeps RAM across reset"
    (let ((cartridge
            (make-cartridge :mapper 28
                            :mirroring :vertical
                            :prg-rom (contract-octets #x4000)
                            :prg-ram-size #x2000)))
      (expect (length (cartridge-chr-rom cartridge)) :to-be (* 4 #x2000))
      (setf (aref (cartridge-prg-ram cartridge) 0) #xA5
            (cl-nes::cartridge-mapper-mode cartridge) #x02)
      (cartridge-reset! cartridge)
      (expect (aref (cartridge-prg-ram cartridge) 0) :to-be #xA5)
      (expect (cartridge-mirroring cartridge) :to-be :vertical)
      (expect (cl-nes::cartridge-mapper-mode cartridge) :to-be #x0E)))

  (it "initializes mapper 28 mode for horizontal mirroring"
    (let ((cartridge
            (make-cartridge :mapper 28
                            :mirroring :horizontal
                            :prg-rom (contract-octets #x4000))))
      (expect (cartridge-mirroring cartridge) :to-be :horizontal)
      (expect (cl-nes::cartridge-mapper-mode cartridge) :to-be #x0F)
      (cartridge-reset! cartridge)
      (expect (cl-nes::cartridge-mapper-mode cartridge) :to-be #x0F))))
