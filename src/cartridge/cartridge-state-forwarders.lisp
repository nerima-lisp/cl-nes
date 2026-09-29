(in-package #:cl-nes)

(defmacro %define-mapper-forwarder (name slot-accessor)
  `(progn
     (defun ,name (cartridge)
       (,slot-accessor (cartridge-mapper-state cartridge)))
     (defsetf ,name (cartridge) (value)
       `(setf (,',slot-accessor (cartridge-mapper-state ,cartridge)) ,value))))

(defmacro %define-mapper4-forwarder (name slot-accessor)
  `(progn
     (defun ,name (cartridge)
       (,slot-accessor (cartridge-mapper4-state cartridge)))
     (defsetf ,name (cartridge) (value)
       `(setf (,',slot-accessor (cartridge-mapper4-state ,cartridge)) ,value))))

(%define-mapper-forwarder cartridge-mapper-shift
                          mapper-state-core-mapper-shift)
(%define-mapper-forwarder cartridge-mapper-control
                          mapper-state-core-mapper-control)
(%define-mapper-forwarder cartridge-mapper-chr-bank-0
                          mapper-state-core-mapper-chr-bank-0)
(%define-mapper-forwarder cartridge-mapper-chr-bank-1
                          mapper-state-core-mapper-chr-bank-1)
(%define-mapper-forwarder cartridge-mapper-prg-bank-1
                          mapper-state-core-mapper-prg-bank-1)
(%define-mapper-forwarder cartridge-mapper-registers
                          mapper-state-core-mapper-registers)
(%define-mapper-forwarder cartridge-mapper-register-select
                          mapper-state-core-mapper-register-select)
(%define-mapper-forwarder cartridge-mapper-mode
                          mapper-state-core-mapper-mode)
(%define-mapper-forwarder cartridge-mapper-outer-bank
                          mapper-state-core-mapper-outer-bank)
(%define-mapper-forwarder cartridge-mapper69-command
                          mapper-state-core-mapper69-command)
(%define-mapper-forwarder cartridge-mapper69-registers
                          mapper-state-core-mapper69-registers)
(%define-mapper-forwarder cartridge-mapper69-irq-counter
                          mapper-state-core-mapper69-irq-counter)
(%define-mapper-forwarder cartridge-mapper69-irq-enabled-p
                          mapper-state-core-mapper69-irq-enabled-p)
(%define-mapper-forwarder cartridge-mapper69-irq-pending-p
                          mapper-state-core-mapper69-irq-pending-p)
(%define-mapper-forwarder cartridge-mapper1-ppu-a12-high-p
                          mapper-state-core-mapper1-ppu-a12-high-p)
(%define-mapper-forwarder cartridge-mapper1-last-write-cycle
                          mapper-state-core-mapper1-last-write-cycle)

(%define-mapper4-forwarder cartridge-mapper4-bank-select
                           cartridge-mapper4-state-mapper4-bank-select)
(%define-mapper4-forwarder cartridge-mapper4-registers
                           cartridge-mapper4-state-mapper4-registers)
(%define-mapper4-forwarder cartridge-mapper4-variant
                           cartridge-mapper4-state-mapper4-variant)
(%define-mapper4-forwarder cartridge-mapper4-prg-ram-enabled-p
                           cartridge-mapper4-state-mapper4-prg-ram-enabled-p)
(%define-mapper4-forwarder cartridge-mapper4-prg-ram-write-protected-p
                           cartridge-mapper4-state-mapper4-prg-ram-write-protected-p)
(%define-mapper4-forwarder cartridge-mapper4-irq-latch
                           cartridge-mapper4-state-mapper4-irq-latch)
(%define-mapper4-forwarder cartridge-mapper4-irq-counter
                           cartridge-mapper4-state-mapper4-irq-counter)
(%define-mapper4-forwarder cartridge-mapper4-irq-reload-p
                           cartridge-mapper4-state-mapper4-irq-reload-p)
(%define-mapper4-forwarder cartridge-mapper4-irq-enabled-p
                           cartridge-mapper4-state-mapper4-irq-enabled-p)
(%define-mapper4-forwarder cartridge-mapper4-irq-pending-p
                           cartridge-mapper4-state-mapper4-irq-pending-p)
(%define-mapper4-forwarder cartridge-mapper4-ppu-a12-high-p
                           cartridge-mapper4-state-mapper4-ppu-a12-high-p)
(%define-mapper4-forwarder cartridge-mapper4-ppu-a12-low-cycles
                           cartridge-mapper4-state-mapper4-ppu-a12-low-cycles)

(defmacro %define-mapper5-forwarder (name slot-accessor)
  `(defun ,name (cartridge)
     (,slot-accessor (cartridge-mapper5-state cartridge))))

(%define-mapper5-forwarder cartridge-mapper5-prg-mode
                           cartridge-mapper5-state-prg-mode)
(%define-mapper5-forwarder cartridge-mapper5-chr-mode
                           cartridge-mapper5-state-chr-mode)
(%define-mapper5-forwarder cartridge-mapper5-prg-banks
                           cartridge-mapper5-state-prg-banks)
(%define-mapper5-forwarder cartridge-mapper5-chr-banks
                           cartridge-mapper5-state-chr-banks)
(%define-mapper5-forwarder cartridge-mapper5-prg-ram-protect-1
                           cartridge-mapper5-state-prg-ram-protect-1)
(%define-mapper5-forwarder cartridge-mapper5-prg-ram-protect-2
                           cartridge-mapper5-state-prg-ram-protect-2)
(%define-mapper5-forwarder cartridge-mapper5-exram-mode
                           cartridge-mapper5-state-exram-mode)
(%define-mapper5-forwarder cartridge-mapper5-nametable-mapping
                           cartridge-mapper5-state-nametable-mapping)
(%define-mapper5-forwarder cartridge-mapper5-fill-tile
                           cartridge-mapper5-state-fill-tile)
(%define-mapper5-forwarder cartridge-mapper5-fill-attribute
                           cartridge-mapper5-state-fill-attribute)
(%define-mapper5-forwarder cartridge-mapper5-split-control
                           cartridge-mapper5-state-split-control)
(%define-mapper5-forwarder cartridge-mapper5-split-scroll
                           cartridge-mapper5-state-split-scroll)
(%define-mapper5-forwarder cartridge-mapper5-split-bank
                           cartridge-mapper5-state-split-bank)
