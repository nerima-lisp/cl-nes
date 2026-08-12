(in-package #:cl-nes)

(defparameter +ppu-register-read-dispatch-forms+
  '((2 (%ppu-read-status ppu bus-access-p))
    (4 (%ppu-read-oam-data ppu bus-access-p))
    (7 (%ppu-read-data ppu))))
