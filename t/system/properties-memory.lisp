(in-package #:cl-nes/test)

(describe "Generated memory and mapper contracts"
  (it-property "CHR writes preserve the low octet of generated values"
      ((value (gen-integer :min 0 :max #xFFFF)))
    (let ((cartridge (make-fixture-cartridge)))
      (cartridge-write-chr! cartridge 0 value)
      (expect (cartridge-read-chr cartridge 0) :to-be (logand value #xFF))))

  (it-property "PPU VRAM addresses wrap at the 14-bit address bus"
      ((address (gen-integer :min 0 :max #x3FFF))
       (value (gen-integer :min 0 :max #xFFFF)))
    (let ((ppu (make-ppu (make-fixture-cartridge))))
      (ppu-write-vram! ppu (+ address #x4000) value)
      (expect (ppu-read-vram ppu address) :to-be (logand value #xFF))))

  (it-property "NROM PRG reads always return an octet"
      ((address (gen-integer :min #x8000 :max #xFFFF)))
    (let ((cartridge (make-patterned-cartridge
                      :mapper 0
                      :prg-banks 4
                      :chr-banks 8)))
      (expect (cartridge-read-prg cartridge address)
              :to-satisfy
              (lambda (byte)
                (and (integerp byte) (<= 0 byte #xFF)))))))
