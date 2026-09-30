(in-package #:cl-nes/test)

(describe "ROM result protocol helpers"
  (it "accepts only the declared RAM result value"
    (expect (protocol-ram-result-p #x01 #x01) :to-be-truthy)
    (expect (protocol-ram-result-p #x02 #x01) :to-be nil))
  (it "does not complete a Blargg result before observing the running marker"
    (expect (protocol-blargg-complete-p 0 t nil) :to-be nil)
    (expect (protocol-blargg-complete-p 0 t t) :to-be-truthy)
    (expect (protocol-blargg-complete-p #x1f nil t) :to-be-truthy))
  (it "does not complete a RAM result before observing its running value"
    (expect (protocol-running-result-complete-p 0 #x80 nil) :to-be nil)
    (expect (protocol-running-result-complete-p 0 #x80 t) :to-be-truthy))
  (it "recognizes a result marker in nametable text"
    (expect (protocol-text-result-p "MMC3 IRQ COUNTER PASSED" "PASSED")
            :to-be-truthy)
    (expect (protocol-text-result-p "MMC3 IRQ COUNTER FAILED #2" "PASSED")
            :to-be nil))
  (it "decodes a synthetic nametable with the supplied font mapping"
    (let ((ppu (make-ppu)))
      (setf (aref (cl-nes::ppu-nametable ppu) 0) 16
            (aref (cl-nes::ppu-nametable ppu) 1) 1)
      (expect (subseq (protocol-nametable-text
                       ppu :columns 2 :rows 1
                       :tile-map (lambda (tile)
                                   (case tile (16 #\P) (1 #\A)
                                         (otherwise #\Space))))
                      0 2)
              :to-equal "PA"))))
