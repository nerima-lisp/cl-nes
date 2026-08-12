(in-package #:cl-nes)

(defconstant +ines-header-size+ 16)
(defconstant +ines-trainer-size+ 512)
(defconstant +prg-bank-size+ (* 16 1024))
(defconstant +prg-bank-8k-size+ (* 8 1024))
(defconstant +prg-ram-bank-size+ (* 8 1024))
(defconstant +chr-bank-1k-size+ 1024)
(defconstant +chr-bank-4k-size+ (* 4 1024))
(defconstant +chr-bank-size+ (* 8 1024))

;; The MMC3 A12 low-pass window is eight CPU cycles, or 24 PPU cycles.
(defconstant +mapper4-a12-low-filter-cycles+ 24)
