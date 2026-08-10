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

(defstruct (cartridge
            (:constructor %make-cartridge
                (&key prg-rom chr-rom mapper mirroring battery-backed-p
                      four-screen-p chr-writable-p prg-ram prg-bank chr-bank
                      initial-mirroring mapper-shift mapper-control mapper-chr-bank-0
                      mapper-chr-bank-1 mapper-prg-bank-1 mapper-registers
                      mapper-register-select mapper-mode mapper-outer-bank
                      mapper4-bank-select mapper4-registers
                      mapper4-variant
                      mapper4-prg-ram-enabled-p mapper4-prg-ram-write-protected-p
                      mapper4-irq-latch mapper4-irq-counter mapper4-irq-reload-p
                      mapper4-irq-enabled-p mapper4-irq-pending-p
                      mapper4-ppu-a12-high-p mapper4-ppu-a12-low-cycles
                      mapper5-prg-mode mapper5-chr-mode
                      mapper5-prg-banks mapper5-chr-banks
                      mapper5-prg-ram-protect-1 mapper5-prg-ram-protect-2
                      mapper5-exram-mode mapper5-nametable-mapping
                      mapper5-fill-tile mapper5-fill-attribute
                      mapper5-split-control mapper5-split-scroll
                      mapper5-split-bank mapper5-irq-scanline
                      mapper5-irq-enabled-p mapper5-irq-pending-p
                      mapper5-in-frame-p mapper5-multiplier-a
                      mapper5-multiplier-b mapper5-exram)))
  (prg-rom #() :type vector)
  (chr-rom #() :type vector)
  (prg-ram #() :type vector)
  (mapper 0 :type fixnum)
  (mirroring :horizontal)
  (initial-mirroring :horizontal)
  (battery-backed-p nil)
  (four-screen-p nil)
  (chr-writable-p nil)
  (prg-bank 0 :type fixnum)
  (chr-bank 0 :type fixnum)
  (mapper-shift #x10 :type (unsigned-byte 8))
  (mapper-control #x0C :type (unsigned-byte 8))
  (mapper-chr-bank-0 0 :type (unsigned-byte 8))
  (mapper-chr-bank-1 0 :type (unsigned-byte 8))
  (mapper-prg-bank-1 0 :type (unsigned-byte 8))
  (mapper-registers (make-array 8 :element-type '(unsigned-byte 8)
                                  :initial-element 0)
                    :type (simple-array (unsigned-byte 8) (8)))
  (mapper-register-select 0 :type (unsigned-byte 8))
  (mapper-mode 0 :type (unsigned-byte 8))
  (mapper-outer-bank #xFF :type (unsigned-byte 8))
  (mapper4-bank-select 0 :type (unsigned-byte 8))
  (mapper4-registers (make-array 8 :element-type '(unsigned-byte 8)
                                  :initial-element 0)
                     :type (simple-array (unsigned-byte 8) (8)))
  ;; iNES headers do not distinguish the MMC3 and MMC6 IRQ reload behavior.
  (mapper4-variant :mmc3)
  (mapper4-prg-ram-enabled-p t)
  (mapper4-prg-ram-write-protected-p nil)
  (mapper4-irq-latch 0 :type (unsigned-byte 8))
  (mapper4-irq-counter 0 :type (unsigned-byte 8))
  (mapper4-irq-reload-p nil)
  (mapper4-irq-enabled-p nil)
  (mapper4-irq-pending-p nil)
  (mapper4-ppu-a12-high-p nil)
  (mapper4-ppu-a12-low-cycles 0 :type fixnum)
  (mapper5-prg-mode 3 :type (unsigned-byte 2))
  (mapper5-chr-mode 3 :type (unsigned-byte 2))
  (mapper5-prg-banks (make-array 8 :element-type '(unsigned-byte 8)
                                  :initial-element 0)
                     :type (simple-array (unsigned-byte 8) (8)))
  (mapper5-chr-banks (make-array 12 :element-type '(unsigned-byte 8)
                                  :initial-element 0)
                     :type (simple-array (unsigned-byte 8) (12)))
  (mapper5-prg-ram-protect-1 0 :type (unsigned-byte 8))
  (mapper5-prg-ram-protect-2 0 :type (unsigned-byte 8))
  (mapper5-exram-mode 0 :type (unsigned-byte 2))
  (mapper5-nametable-mapping 0 :type (unsigned-byte 8))
  (mapper5-fill-tile 0 :type (unsigned-byte 8))
  (mapper5-fill-attribute 0 :type (unsigned-byte 2))
  (mapper5-split-control 0 :type (unsigned-byte 8))
  (mapper5-split-scroll 0 :type (unsigned-byte 8))
  (mapper5-split-bank 0 :type (unsigned-byte 8))
  (mapper5-irq-scanline 0 :type (unsigned-byte 8))
  (mapper5-irq-enabled-p nil)
  (mapper5-irq-pending-p nil)
  (mapper5-in-frame-p nil)
  (mapper5-multiplier-a 0 :type (unsigned-byte 8))
  (mapper5-multiplier-b 0 :type (unsigned-byte 8))
  (mapper5-exram (make-array #x400 :element-type '(unsigned-byte 8)
                              :initial-element 0)
                 :type (simple-array (unsigned-byte 8) (1024))))
