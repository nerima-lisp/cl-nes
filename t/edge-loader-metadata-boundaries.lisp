(in-package #:cl-nes/test)

(describe "iNES loader metadata boundaries"
  (it "skips trainers and preserves cartridge metadata"
    (let ((cartridge
            (load-cartridge
             (make-ines-image :flags6 #x0B :trainer-p t))))
      (expect (cartridge-mapper cartridge) :to-be 0)
      (expect (cartridge-mirroring cartridge) :to-be :vertical)
      (expect (cartridge-battery-backed-p cartridge) :to-be t)
      (expect (cartridge-four-screen-p cartridge) :to-be t)
      (expect (cartridge-chr-writable-p cartridge) :to-be t)
      (expect (length (cartridge-prg-ram cartridge)) :to-be #x2000)
      (expect (aref (cartridge-prg-rom cartridge) 0) :to-be #xA5)))

  (it "decodes NES 2.0 RAM sizes and rejects exponent ROM sizes"
    (let ((cartridge
            (load-cartridge
             (make-ines-image :flags7 #x08 :byte10 #x21))))
      (expect (length (cartridge-prg-ram cartridge)) :to-be 384)
      (expect (cartridge-chr-writable-p cartridge) :to-be t))
    (let ((condition
            (captured-condition
             (lambda ()
               (load-cartridge
                (make-ines-image :flags7 #x08 :byte9 #x0F))))))
      (expect (typep condition 'invalid-rom) :to-be t)))

  (it "reports unsupported mapper numbers"
    (let ((condition
            (captured-condition
             (lambda ()
               (load-cartridge (make-ines-image :flags6 #x60))))))
      (expect (typep condition 'unsupported-mapper) :to-be t)
      (when (typep condition 'unsupported-mapper)
        (expect (unsupported-mapper-number condition) :to-be 6)))))
