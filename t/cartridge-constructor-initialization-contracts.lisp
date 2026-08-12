(in-package #:cl-nes/test)

(describe "Cartridge constructor initialization contracts"
  (it "allocates writable default CHR storage for mappers without CHR ROM"
    (let ((nrom (make-cartridge :mapper 0
                                :prg-rom (contract-octets #x4000)
                                :chr-rom nil))
          (action53 (make-cartridge :mapper 28
                                    :prg-rom (contract-octets #x4000)
                                    :chr-rom nil)))
      (expect (cartridge-chr-writable-p nrom) :to-be t)
      (expect (length (cartridge-chr-rom nrom)) :to-be #x2000)
      (expect (aref (cartridge-chr-rom nrom) 0) :to-be 0)
      (expect (cartridge-chr-writable-p action53) :to-be t)
      (expect (length (cartridge-chr-rom action53)) :to-be (* 4 #x2000))
      (expect (aref (cartridge-chr-rom action53) 0) :to-be 0)))

  (it "initializes PRG-RAM and MMC5 constructor state"
    (let* ((prg-size (* 4 #x2000))
           (cartridge (make-cartridge :mapper 5
                                      :prg-rom (contract-octets prg-size)
                                      :chr-rom (contract-octets #x2000)
                                      :prg-ram-size #x80))
           (prg-banks (cl-nes::cartridge-mapper5-prg-banks cartridge))
           (chr-banks (cl-nes::cartridge-mapper5-chr-banks cartridge))
           (exram (cl-nes::cartridge-mapper5-exram cartridge)))
      (expect (length (cartridge-prg-ram cartridge)) :to-be #x80)
      (expect (aref (cartridge-prg-ram cartridge) 0) :to-be 0)
      (expect (length prg-banks) :to-be 8)
      (expect (aref prg-banks 4) :to-be #x80)
      (expect (aref prg-banks 5) :to-be #x80)
      (expect (aref prg-banks 6) :to-be #x80)
      (expect (aref prg-banks 7) :to-be #x83)
      (expect (length chr-banks) :to-be 12)
      (expect (aref chr-banks 0) :to-be 0)
      (expect (length exram) :to-be #x400)
      (expect (aref exram 0) :to-be 0)
      (expect (cl-nes::cartridge-mapper5-prg-mode cartridge) :to-be 3)
      (expect (cl-nes::cartridge-mapper5-chr-mode cartridge) :to-be 3)))

  (it "covers direct allocation and initialization helper branches"
    (let* ((explicit-chr (contract-octets #x2000))
           (chr-rom (cl-nes::%coerce-chr-rom nil 28))
           (kept-chr (cl-nes::%coerce-chr-rom explicit-chr 0))
           (mapper-registers (cl-nes::%make-mapper-registers))
           (mapper4-registers (cl-nes::%make-mapper4-registers))
           (prg-ram (cl-nes::%make-prg-ram 3))
           (mapper5-banks (cl-nes::%make-mapper5-prg-banks))
           (mapper5-chr-banks (cl-nes::%make-mapper5-chr-banks))
           (mapper5-exram (cl-nes::%make-mapper5-exram))
           (base-initargs
             (cl-nes::%base-cartridge-initargs
              (contract-octets #x4000) kept-chr prg-ram
              28 :vertical t nil t mapper-registers))
           (mapper4-initargs
             (cl-nes::%mapper4-initargs mapper4-registers :mmc6))
           (mapper5-initargs
             (cl-nes::%mapper5-initargs
              mapper5-banks mapper5-chr-banks mapper5-exram)))
      (expect (cl-nes::%default-chr-size 0) :to-be #x2000)
      (expect (cl-nes::%default-chr-size 28) :to-be (* 4 #x2000))
      (expect (length chr-rom) :to-be (* 4 #x2000))
      (expect (aref chr-rom 0) :to-be 0)
      (expect (length kept-chr) :to-be #x2000)
      (expect (aref kept-chr 0) :to-be 0)
      (expect (aref kept-chr (1- #x2000)) :to-be 0)
      (expect (length mapper-registers) :to-be 8)
      (expect (aref mapper-registers 0) :to-be 0)
      (expect (length mapper4-registers) :to-be 8)
      (expect (aref mapper4-registers 0) :to-be 0)
      (expect (length prg-ram) :to-be 3)
      (expect (aref prg-ram 0) :to-be 0)
      (expect (length mapper5-chr-banks) :to-be 12)
      (expect (aref mapper5-chr-banks 0) :to-be 0)
      (expect (length mapper5-exram) :to-be #x400)
      (expect (aref mapper5-exram 0) :to-be 0)
      (expect (cl-nes::%initialize-mapper5-prg-banks!
               0 (contract-octets #x4000) mapper5-banks)
              :to-equal mapper5-banks)
      (expect (aref mapper5-banks 7) :to-be 0)
      (expect (getf base-initargs :initial-mirroring) :to-be :vertical)
      (expect (getf base-initargs :mapper-mode) :to-be #x0E)
      (expect (getf base-initargs :mapper-registers) :to-be mapper-registers)
      (expect (getf mapper4-initargs :mapper4-variant) :to-be :mmc6)
      (expect (getf mapper4-initargs :mapper4-prg-ram-enabled-p) :to-be t)
      (expect (getf mapper5-initargs :mapper5-prg-banks) :to-be mapper5-banks)
      (expect (getf mapper5-initargs :mapper5-exram) :to-be mapper5-exram)
      (expect (cl-nes::%initial-mapper-mode 28 :horizontal) :to-be #x0F)
      (expect (cl-nes::%initial-mapper-mode 0 :vertical) :to-be 0))))
