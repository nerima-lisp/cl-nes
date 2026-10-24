(in-package #:cl-nes/test)

(defun make-mapper30-contract-storage (bank-count bank-size)
  (let ((storage (make-array (* bank-count bank-size)
                             :element-type (quote (unsigned-byte 8))
                             :initial-element 0)))
    (dotimes (bank bank-count storage)
      (fill storage bank
            :start (* bank bank-size)
            :end (* (1+ bank) bank-size)))))

(defun make-mapper30-contract-cartridge (&key (submapper 0)
                                                 battery-backed-p
                                                 (mirroring :horizontal)
                                                 four-screen-p)
  (make-cartridge :mapper 30
                  :submapper submapper
                  :battery-backed-p battery-backed-p
                  :mirroring mirroring
                  :four-screen-p four-screen-p
                  :prg-rom (make-mapper30-contract-storage
                            4 (* 2 cl-nes::+prg-bank-8k-size+))
                  :chr-rom (make-mapper30-contract-storage
                            4 cl-nes::+chr-bank-size+)
                  :chr-writable-p t))

(describe "Mapper 30 contracts"
  (it "switches the lower PRG bank and fixes the final bank"
    (let ((cartridge (make-mapper30-contract-cartridge)))
      (expect (cartridge-read-prg cartridge #x8000) :to-be 0)
      (cartridge-write-prg! cartridge #x8000 #x02)
      (expect (cartridge-read-prg cartridge #x8000) :to-be 2)
      (expect (cartridge-read-prg cartridge #xC000) :to-be 3)))

  (it "separates CHR-RAM writes by the selected 8 KiB bank"
    (let ((cartridge (make-mapper30-contract-cartridge)))
      (cartridge-write-prg! cartridge #x8000 #x20)
      (expect (cartridge-read-chr cartridge #x20) :to-be 1)
      (cartridge-write-chr! cartridge #x20 #xA5)
      (cartridge-write-prg! cartridge #x8000 #x40)
      (expect (cartridge-read-chr cartridge #x20) :to-be 2)
      (cartridge-write-chr! cartridge #x20 #x5A)
      (cartridge-write-prg! cartridge #x8000 #x20)
      (expect (cartridge-read-chr cartridge #x20) :to-be #xA5)
      (cartridge-write-prg! cartridge #x8000 #x40)
      (expect (cartridge-read-chr cartridge #x20) :to-be #x5A)))

  (it "decodes write windows and respects header and single-screen mirroring"
    (let ((single-screen
            (make-mapper30-contract-cartridge
             :mirroring :single-screen-lower))
          (flash
            (make-mapper30-contract-cartridge :battery-backed-p t))
          (submapper-2
            (make-mapper30-contract-cartridge :submapper 2))
          (mapper-controlled
            (make-mapper30-contract-cartridge :submapper 3)))
      (cartridge-write-prg! single-screen #x8000 #x80)
      (expect (cartridge-mirroring single-screen) :to-be :single-screen-upper)
      (cartridge-write-prg! single-screen #x8000 0)
      (expect (cartridge-mirroring single-screen) :to-be :single-screen-lower)
      (dolist (mirroring (list :horizontal :vertical))
        (let ((header (make-mapper30-contract-cartridge :mirroring mirroring)))
          (cartridge-write-prg! header #x8000 #x80)
          (expect (cartridge-mirroring header) :to-be mirroring)))
      (cartridge-write-prg! flash #x8000 #x03)
      (expect (cartridge-read-prg flash #x8000) :to-be 0)
      (cartridge-write-prg! flash #xC000 #x03)
      (expect (cartridge-read-prg flash #x8000) :to-be 3)
      (cartridge-write-prg! submapper-2 #xBFFF #x02)
      (expect (cartridge-read-prg submapper-2 #x8000) :to-be 2)
      (dolist (submapper (list 1 3 4))
        (let ((upper-only
                (make-mapper30-contract-cartridge :submapper submapper)))
          (cartridge-write-prg! upper-only #x8000 #x01)
          (expect (cartridge-read-prg upper-only #x8000) :to-be 0)
          (cartridge-write-prg! upper-only #xC000 #x01)
          (expect (cartridge-read-prg upper-only #x8000) :to-be 1)))
      (cartridge-write-prg! mapper-controlled #xC000 #x80)
      (expect (cartridge-mirroring mapper-controlled) :to-be :vertical)
      (cartridge-write-prg! mapper-controlled #xC000 0)
      (expect (cartridge-mirroring mapper-controlled) :to-be :horizontal)))

  (it "restores initial banks and mirroring on reset"
    (let ((cartridge
            (make-mapper30-contract-cartridge
             :mirroring :single-screen-lower)))
      (cartridge-write-prg! cartridge #x8000 #xE2)
      (cartridge-write-chr! cartridge 0 #xA5)
      (expect (cartridge-read-prg cartridge #x8000) :to-be 2)
      (expect (cartridge-mirroring cartridge) :to-be :single-screen-upper)
      (cartridge-reset! cartridge)
      (expect (cartridge-read-prg cartridge #x8000) :to-be 0)
      (expect (cartridge-read-prg cartridge #xC000) :to-be 3)
      (expect (cartridge-read-chr cartridge 0) :to-be 0)
      (expect (cartridge-mirroring cartridge) :to-be :single-screen-lower)))

  (it "maps four-screen nametables to the final CHR-RAM bank"
    (let* ((cartridge
             (make-mapper30-contract-cartridge
              :mirroring :vertical
              :four-screen-p t))
           (ciram (make-array #x1000
                              :element-type (quote (unsigned-byte 8))
                              :initial-element 0))
           (chr (cartridge-chr-rom cartridge)))
      (cartridge-write-prg! cartridge #xC000 #x80)
      (expect (cartridge-mirroring cartridge) :to-be :vertical)
      (cl-nes::cartridge-ppu-write-nametable! cartridge ciram #x2000 #xA5)
      (cl-nes::cartridge-ppu-write-nametable! cartridge ciram #x2800 #x5A)
      (expect (cl-nes::cartridge-ppu-read-nametable cartridge ciram #x2000)
              :to-be #xA5)
      (expect (cl-nes::cartridge-ppu-read-nametable cartridge ciram #x2800)
              :to-be #x5A)
      (expect (aref chr #x6000) :to-be #xA5)
      (expect (aref chr #x6800) :to-be #x5A)
      (expect (aref ciram 0) :to-be 0)
      (expect (aref ciram #x800) :to-be 0)))
  (it "loads Mapper 30 header mirroring and conflict flags"
    (let ((legacy
            (load-cartridge
             (make-ines-image :prg-banks 4 :flags6 #xE0 :flags7 #x10)))
          (battery-backed
            (load-cartridge
             (make-ines-image :prg-banks 4 :flags6 #xE3 :flags7 #x10)))
          (single-screen
            (load-cartridge
             (make-ines-image :prg-banks 4 :flags6 #xE8 :flags7 #x10)))
          (four-screen
            (load-cartridge
             (make-ines-image :prg-banks 4 :flags6 #xE9 :flags7 #x10))))
      (expect (cartridge-mirroring legacy) :to-be :vertical)
      (expect (cl-nes::cartridge-bus-conflict-p legacy) :to-be t)
      (expect (length (cartridge-chr-rom legacy)) :to-be #x8000)
      (expect (cartridge-chr-writable-p legacy) :to-be t)
      (expect (length (cartridge-prg-ram legacy)) :to-be 0)
      (cartridge-write-prg! legacy #x8000 #x03)
      (expect (cl-nes::cartridge-prg-bank legacy) :to-be 1)
      (expect (cartridge-mirroring battery-backed) :to-be :horizontal)
      (expect (cl-nes::cartridge-bus-conflict-p battery-backed) :to-be nil)
      (expect (length (cartridge-prg-ram battery-backed)) :to-be 0)
      (cartridge-write-prg! battery-backed #x8000 #x03)
      (expect (cl-nes::cartridge-prg-bank battery-backed) :to-be 0)
      (cartridge-write-prg! battery-backed #xC000 #x03)
      (expect (cl-nes::cartridge-prg-bank battery-backed) :to-be 3)
      (expect (cartridge-mirroring single-screen)
              :to-be :single-screen-lower)
      (expect (cartridge-four-screen-p four-screen) :to-be t))))
