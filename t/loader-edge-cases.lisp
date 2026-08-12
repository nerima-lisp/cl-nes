(in-package #:cl-nes/test)

(describe "iNES loader boundaries"
  (it "rejects malformed sources and ROM images"
    (let ((source-condition
            (captured-condition (lambda () (load-cartridge '(1 2 3)))))
          (header-condition
            (captured-condition
             (lambda ()
               (load-cartridge
                (make-array cl-nes::+ines-header-size+
                            :element-type '(unsigned-byte 8)
                            :initial-element 0)))))
          (empty-prg-condition
            (captured-condition
             (lambda () (load-cartridge (make-ines-image :prg-banks 0)))))
          (truncated-condition
            (captured-condition
             (lambda ()
               (load-cartridge
                (subseq (make-ines-image) 0 cl-nes::+ines-header-size+))))))
      (expect (typep source-condition 'invalid-rom) :to-be t)
      (expect (typep header-condition 'invalid-rom) :to-be t)
      (expect (typep empty-prg-condition 'invalid-rom) :to-be t)
      (expect (typep truncated-condition 'invalid-rom) :to-be t)))

  (it "validates every iNES magic byte and decodes legacy PRG-RAM size"
    (dolist (index '(1 2 3))
      (let ((image (make-ines-image)))
        (setf (aref image index) 0)
        (expect (typep
                 (captured-condition (lambda () (load-cartridge image)))
                 'invalid-rom)
                :to-be t)))
    (let ((cartridge (load-cartridge (make-ines-image :byte8 2))))
      (expect (length (cartridge-prg-ram cartridge)) :to-be #x4000)))

  (it "covers internal source coercion and decoded iNES layout helpers"
    (let ((image (make-ines-image :prg-banks 2 :chr-banks 1 :flags6 #x05)))
      (expect (equalp (cl-nes::%coerce-cartridge-source image) image) :to-be t)
      (multiple-value-bind (prg-banks chr-banks mapper nes2-p)
          (cl-nes::%decode-ines-geometry image)
        (expect prg-banks :to-be 2)
        (expect chr-banks :to-be 1)
        (expect mapper :to-be 0)
        (expect nes2-p :to-be nil))
      (multiple-value-bind (trainer-p four-screen-p mirroring battery-backed-p)
          (cl-nes::%decode-ines-metadata (aref image 6))
        (expect trainer-p :to-be t)
        (expect four-screen-p :to-be nil)
        (expect mirroring :to-be :vertical)
        (expect battery-backed-p :to-be nil))
      (multiple-value-bind (prg-size chr-size offset required)
          (cl-nes::%ines-data-layout 2 1 t)
        (expect prg-size :to-be (* 2 cl-nes::+prg-bank-size+))
        (expect chr-size :to-be cl-nes::+chr-bank-size+)
        (expect offset
                :to-be (+ cl-nes::+ines-header-size+
                          cl-nes::+ines-trainer-size+))
        (expect required :to-be (+ offset prg-size chr-size)))))

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
    (let ((cartridge
            (load-cartridge
             (make-ines-image :flags7 #x08 :byte10 #x20))))
      (expect (length (cartridge-prg-ram cartridge)) :to-be 256))
    (expect (cl-nes::%decode-prg-ram-size (make-ines-image :byte8 2) nil)
            :to-be #x4000)
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
