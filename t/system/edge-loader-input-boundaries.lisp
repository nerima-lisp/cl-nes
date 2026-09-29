(in-package #:cl-nes/test)

(describe "iNES loader input boundaries"
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
      (expect (length (cartridge-prg-ram cartridge)) :to-be #x4000))))
