(in-package #:cl-nes/test)

(describe "Cartridge regression contracts"
  (it "filters the second write of an MMC1 CPU read-modify-write"
    (let ((cartridge (make-patterned-cartridge
                      :mapper 1
                      :prg-banks 4
                      :chr-banks 8)))
      (setf (aref (cartridge-prg-rom cartridge) 0) #x0E
            (aref (cartridge-prg-rom cartridge) 1) 0
            (aref (cartridge-prg-rom cartridge) 2) #x80
            (aref (cartridge-prg-rom cartridge) #x7FFC) 0
            (aref (cartridge-prg-rom cartridge) #x7FFD) #x80)
      (let* ((nes (make-nes :cartridge cartridge))
             (cpu (nes-cpu nes)))
      (expect (nes-step/k nes #'identity) :to-be 6)
      (expect (cl-nes::cartridge-mapper-shift cartridge) :to-be #x08)
      (expect (cpu-pc cpu) :to-be #x8003))))

  (it "accepts an MMC1 write to the same address in the next instruction"
    (let ((cartridge (make-patterned-cartridge
                      :mapper 1
                      :prg-banks 4
                      :chr-banks 8)))
      (cl-nes::cartridge-cpu-write! cartridge #x8000 0 10)
      (cl-nes::cartridge-cpu-write! cartridge #x8000 0 12)
      (expect (cl-nes::cartridge-mapper-shift cartridge) :to-be #x04)))

  (it "gives an explicit MMC3 variant precedence over the NES 2.0 submapper"
    (let ((image (make-ines-image :prg-banks 2
                                  :chr-banks 1
                                  :flags6 #x40
                                  :flags7 #x08
                                  :byte8 #x10)))
      (expect (cartridge-mapper4-variant (load-cartridge image))
              :to-be :mmc6)
      (expect (cartridge-mapper4-variant
               (load-cartridge image :mapper4-variant :mmc3-alt))
              :to-be :mmc3-alt))))
