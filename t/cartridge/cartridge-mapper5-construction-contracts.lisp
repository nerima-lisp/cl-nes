(in-package #:cl-nes/test)

(describe "Cartridge mapper 5 construction contracts"
  (it "restores mapper 5 bank defaults without clearing RAM"
    (let ((cartridge (make-patterned-cartridge :mapper 5
                                               :prg-banks 4
                                               :chr-banks 8)))
      (setf (aref (cartridge-prg-ram cartridge) 0) #x5A
            (aref (cl-nes::cartridge-mapper5-prg-banks cartridge) 0) #x7F)
      (cartridge-reset! cartridge)
      (expect (aref (cartridge-prg-ram cartridge) 0) :to-be #x5A)
      (expect (aref (cl-nes::cartridge-mapper5-prg-banks cartridge) 0) :to-be 0)
      (expect (aref (cl-nes::cartridge-mapper5-prg-banks cartridge) 4) :to-be #x80))))
