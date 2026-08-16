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

(defstruct (cartridge-mapper5-state
            (:constructor %make-cartridge-mapper5-state-instance ()))
  prg-mode
  chr-mode
  prg-banks
  chr-banks
  prg-ram-protect-1
  prg-ram-protect-2
  exram-mode
  nametable-mapping
  fill-tile
  fill-attribute
  split-control
  split-scroll
  split-bank
  irq-scanline
  irq-enabled-p
  irq-pending-p
  in-frame-p
  multiplier-a
  multiplier-b
  exram)

(defun %install-vector-accessor-pair (reader writer index)
  (setf (fdefinition reader)
        (lambda (state)
          (aref state index))
        (fdefinition writer)
        (lambda (state value)
          (setf (aref state index) value)))
  nil)

(defun %install-vector-accessor-pairs (specs)
  (dolist (spec specs)
    (destructuring-bind (reader writer index) spec
      (%install-vector-accessor-pair reader writer index)))
  nil)

(defun %make-mapper-state-core-instance ()
  (make-array 9 :initial-element nil))

(%install-vector-accessor-pairs
 '((mapper-state-core-mapper-shift set-mapper-state-core-mapper-shift! 0)
   (mapper-state-core-mapper-control set-mapper-state-core-mapper-control! 1)
   (mapper-state-core-mapper-chr-bank-0 set-mapper-state-core-mapper-chr-bank-0! 2)
   (mapper-state-core-mapper-chr-bank-1 set-mapper-state-core-mapper-chr-bank-1! 3)
   (mapper-state-core-mapper-prg-bank-1 set-mapper-state-core-mapper-prg-bank-1! 4)
   (mapper-state-core-mapper-registers set-mapper-state-core-mapper-registers! 5)
   (mapper-state-core-mapper-register-select set-mapper-state-core-mapper-register-select! 6)
   (mapper-state-core-mapper-mode set-mapper-state-core-mapper-mode! 7)
   (mapper-state-core-mapper-outer-bank set-mapper-state-core-mapper-outer-bank! 8)))

(defun %make-cartridge-mapper4-state-instance ()
  (make-array 12 :initial-element nil))

(%install-vector-accessor-pairs
 '((cartridge-mapper4-state-mapper4-bank-select
    set-cartridge-mapper4-state-mapper4-bank-select!
    0)
   (cartridge-mapper4-state-mapper4-registers
    set-cartridge-mapper4-state-mapper4-registers!
    1)
   (cartridge-mapper4-state-mapper4-variant
    set-cartridge-mapper4-state-mapper4-variant!
    2)
   (cartridge-mapper4-state-mapper4-prg-ram-enabled-p
    set-cartridge-mapper4-state-mapper4-prg-ram-enabled-p!
    3)
   (cartridge-mapper4-state-mapper4-prg-ram-write-protected-p
    set-cartridge-mapper4-state-mapper4-prg-ram-write-protected-p!
    4)
   (cartridge-mapper4-state-mapper4-irq-latch
    set-cartridge-mapper4-state-mapper4-irq-latch!
    5)
   (cartridge-mapper4-state-mapper4-irq-counter
    set-cartridge-mapper4-state-mapper4-irq-counter!
    6)
   (cartridge-mapper4-state-mapper4-irq-reload-p
    set-cartridge-mapper4-state-mapper4-irq-reload-p!
    7)
   (cartridge-mapper4-state-mapper4-irq-enabled-p
    set-cartridge-mapper4-state-mapper4-irq-enabled-p!
    8)
   (cartridge-mapper4-state-mapper4-irq-pending-p
    set-cartridge-mapper4-state-mapper4-irq-pending-p!
    9)
   (cartridge-mapper4-state-mapper4-ppu-a12-high-p
    set-cartridge-mapper4-state-mapper4-ppu-a12-high-p!
    10)
   (cartridge-mapper4-state-mapper4-ppu-a12-low-cycles
    set-cartridge-mapper4-state-mapper4-ppu-a12-low-cycles!
    11)))

(deftype cartridge ()
  'simple-vector)

(defun %make-cartridge-instance ()
  (make-array 14 :initial-element nil))

(%install-vector-accessor-pairs
 '((cartridge-prg-rom set-cartridge-prg-rom! 0)
   (cartridge-chr-rom set-cartridge-chr-rom! 1)
   (cartridge-prg-ram set-cartridge-prg-ram! 2)
   (cartridge-mapper set-cartridge-mapper! 3)
   (cartridge-mirroring set-cartridge-mirroring! 4)
   (cartridge-initial-mirroring set-cartridge-initial-mirroring! 5)
   (cartridge-battery-backed-p set-cartridge-battery-backed-p! 6)
   (cartridge-four-screen-p set-cartridge-four-screen-p! 7)
   (cartridge-chr-writable-p set-cartridge-chr-writable-p! 8)
   (cartridge-prg-bank set-cartridge-prg-bank! 9)
   (cartridge-chr-bank set-cartridge-chr-bank! 10)
   (cartridge-mapper5-state set-cartridge-mapper5-state! 11)
   (cartridge-mapper4-state set-cartridge-mapper4-state! 12)
   (cartridge-mapper-state set-cartridge-mapper-state! 13)))
