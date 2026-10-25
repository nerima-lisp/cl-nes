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
            :to-be nil)
    (expect (protocol-text-result-p "159A7A8F" (list "159A7A8F" "5E3DF9C4"))
            :to-be-truthy)
    (expect (protocol-text-result-p "5E3DF9C4" (list "159A7A8F" "5E3DF9C4"))
            :to-be-truthy)
    (expect (protocol-text-result-p "DEADBEEF" (list "159A7A8F" "5E3DF9C4"))
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
              :to-equal "PA")))
  (it "waits in emulated time before resetting a Blargg ROM"
    (let* ((image (make-ines-image :prg-banks 2 :prg-fill #xEA))
           (header-size cl-nes::+ines-header-size+)
           (prg-size (* 2 cl-nes::+prg-bank-size+))
           (program
             (quote (#xAD #x05 #x60 #xD0 #x1C
                     #xA9 #x01 #x8D #x05 #x60
                     #xA9 #xDE #x8D #x01 #x60
                     #xA9 #xB0 #x8D #x02 #x60
                     #xA9 #x61 #x8D #x03 #x60
                     #xA9 #x81 #x8D #x00 #x60
                     #x4C #x1E #x80
                     #xA9 #x80 #x8D #x00 #x60
                     #xA2 #x1E #xA0 #xFF
                     #x88 #xD0 #xFD #xCA #xD0 #xF8
                     #xA9 #x00 #x8D #x00 #x60
                     #x4C #x35 #x80))))
      ;; First boot stores the signature, sets $81, and loops. Reset preserves
      ;; that flag; the reboot path holds $80 across a frame before writing zero.
      (loop for byte in program
            for offset from header-size
            do (setf (aref image offset) byte))
      (dolist (vector-offset (list (- prg-size 6)
                                   (- prg-size 4)
                                   (- prg-size 2)))
        (setf (aref image (+ header-size vector-offset)) 0
              (aref image (+ header-size vector-offset 1)) #x80))
      (let ((result (run-blargg-protocol image 40)))
        (expect (getf result :passed) :to-be-truthy)
        (expect (getf result :frames) :to-equal 10)
        (expect (getf result :status) :to-equal 0)
        (expect (getf result :signature) :to-be-truthy)
        (expect (getf result :running-observed) :to-be-truthy)))))
