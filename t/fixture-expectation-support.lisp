(in-package #:cl-nes/test)

(defun expect-prg-slot-banks (cartridge expected-banks)
  (loop for address from #x8000 by #x2000
        for expected in expected-banks
        do (expect (cartridge-read-prg cartridge address)
                   :to-be
                   expected)))

(defun expect-chr-slot-banks (cartridge expected-banks &optional backgroundp)
  (loop for slot below 8
        for expected in expected-banks
        for address = (* slot cl-nes::+chr-bank-1k-size+)
        do (expect (cartridge-read-chr cartridge address backgroundp)
                   :to-be
                   expected)))

(defun expect-mmc5-chr-slot-banks
    (cartridge sprite-banks background-banks)
  (expect-chr-slot-banks cartridge sprite-banks t)
  (expect-chr-slot-banks cartridge background-banks nil))

(defun expect-mmc5-nametable-location
    (cartridge address expected-source expected-within)
  (multiple-value-bind (source within)
      (cl-nes::cartridge-mmc5-nametable-location cartridge address)
    (expect source :to-be expected-source)
    (expect within :to-be expected-within)))

(defun pulse-ppu-a12! (cartridge &optional (low-cycles 24))
  (cl-nes::cartridge-clock-ppu-a12! cartridge nil low-cycles)
  (cl-nes::cartridge-clock-ppu-a12! cartridge t))

(defun expect-vram-values (ppu expectations)
  (dolist (expectation expectations)
    (destructuring-bind (address expected) expectation
      (expect (ppu-read-vram ppu address) :to-be expected))))
