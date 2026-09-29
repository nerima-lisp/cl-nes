(in-package #:cl-nes)

(defun %make-cartridge-mapper5-state (&key (prg-mode 3) (chr-mode 3)
                                           (prg-banks (make-array 8 :element-type '(unsigned-byte 8)
                                                                  :initial-element 0))
                                           (chr-banks (make-array 12 :element-type '(unsigned-byte 8)
                                                                  :initial-element 0))
                                           (prg-ram-protect-1 0) (prg-ram-protect-2 0)
                                           (exram-mode 0) (nametable-mapping 0)
                                           (fill-tile 0) (fill-attribute 0)
                                           (split-control 0) (split-scroll 0)
                                           (split-bank 0) (irq-scanline 0)
                                           (irq-enabled-p nil) (irq-pending-p nil)
                                           (in-frame-p nil) (multiplier-a 0)
                                           (multiplier-b 0)
                                           (exram (make-array #x400 :element-type '(unsigned-byte 8)
                                                              :initial-element 0)))
  (let ((state (%make-cartridge-mapper5-state-instance)))
    (setf (cartridge-mapper5-state-prg-mode state) prg-mode)
    (setf (cartridge-mapper5-state-chr-mode state) chr-mode)
    (setf (cartridge-mapper5-state-prg-banks state) prg-banks)
    (setf (cartridge-mapper5-state-chr-banks state) chr-banks)
    (setf (cartridge-mapper5-state-prg-ram-protect-1 state) prg-ram-protect-1)
    (setf (cartridge-mapper5-state-prg-ram-protect-2 state) prg-ram-protect-2)
    (setf (cartridge-mapper5-state-exram-mode state) exram-mode)
    (setf (cartridge-mapper5-state-nametable-mapping state) nametable-mapping)
    (setf (cartridge-mapper5-state-fill-tile state) fill-tile)
    (setf (cartridge-mapper5-state-fill-attribute state) fill-attribute)
    (setf (cartridge-mapper5-state-split-control state) split-control)
    (setf (cartridge-mapper5-state-split-scroll state) split-scroll)
    (setf (cartridge-mapper5-state-split-bank state) split-bank)
    (setf (cartridge-mapper5-state-irq-scanline state) irq-scanline)
    (setf (cartridge-mapper5-state-irq-enabled-p state) irq-enabled-p)
    (setf (cartridge-mapper5-state-irq-pending-p state) irq-pending-p)
    (setf (cartridge-mapper5-state-in-frame-p state) in-frame-p)
    (setf (cartridge-mapper5-state-multiplier-a state) multiplier-a)
    (setf (cartridge-mapper5-state-multiplier-b state) multiplier-b)
    (setf (cartridge-mapper5-state-exram state) exram)
    state))

(defun %make-cartridge-mapper-state (&key (mapper-shift #x10) (mapper-control #x0C)
                                          (mapper-chr-bank-0 0) (mapper-chr-bank-1 0)
                                          (mapper-prg-bank-1 0)
                                          (mapper-registers (make-array 8 :element-type '(unsigned-byte 8)
                                                                        :initial-element 0))
                                          (mapper-register-select 0)
                                          (mapper-mode 0) (mapper-outer-bank #xFF)
                                          (mapper69-command 0)
                                          (mapper69-registers (make-array 16 :element-type '(unsigned-byte 8)
                                                                          :initial-element 0))
                                          (mapper69-irq-counter 0)
                                          (mapper69-irq-enabled-p nil)
                                          (mapper69-irq-pending-p nil)
                                          (mapper1-last-write-cycle nil))
  (let ((state (%make-mapper-state-core-instance)))
    (setf (mapper-state-core-mapper-shift state) mapper-shift
          (mapper-state-core-mapper-control state) mapper-control
          (mapper-state-core-mapper-chr-bank-0 state) mapper-chr-bank-0
          (mapper-state-core-mapper-chr-bank-1 state) mapper-chr-bank-1
          (mapper-state-core-mapper-prg-bank-1 state) mapper-prg-bank-1
          (mapper-state-core-mapper-registers state) mapper-registers
          (mapper-state-core-mapper-register-select state) mapper-register-select
          (mapper-state-core-mapper-mode state) mapper-mode
          (mapper-state-core-mapper-outer-bank state) mapper-outer-bank
          (mapper-state-core-mapper69-command state) mapper69-command
          (mapper-state-core-mapper69-registers state) mapper69-registers
          (mapper-state-core-mapper69-irq-counter state) mapper69-irq-counter
          (mapper-state-core-mapper69-irq-enabled-p state) mapper69-irq-enabled-p
          (mapper-state-core-mapper69-irq-pending-p state) mapper69-irq-pending-p
          (mapper-state-core-mapper1-last-write-cycle state) mapper1-last-write-cycle)
    state))

(defun %make-cartridge-mapper4-state (&key (mapper4-bank-select 0)
                                           (mapper4-registers (make-array 8 :element-type '(unsigned-byte 8)
                                                                          :initial-element 0))
                                           (mapper4-variant :mmc3)
                                           (mapper4-prg-ram-enabled-p t)
                                           (mapper4-prg-ram-write-protected-p nil)
                                           (mapper4-irq-latch 0) (mapper4-irq-counter 0)
                                           (mapper4-irq-reload-p nil)
                                           (mapper4-irq-enabled-p nil)
                                           (mapper4-irq-pending-p nil)
                                           (mapper4-ppu-a12-high-p nil)
                                           (mapper4-ppu-a12-low-cycles 0))
  (let ((state (%make-cartridge-mapper4-state-instance)))
    (setf (cartridge-mapper4-state-mapper4-bank-select state) mapper4-bank-select
          (cartridge-mapper4-state-mapper4-registers state) mapper4-registers
          (cartridge-mapper4-state-mapper4-variant state) mapper4-variant
          (cartridge-mapper4-state-mapper4-prg-ram-enabled-p state) mapper4-prg-ram-enabled-p
          (cartridge-mapper4-state-mapper4-prg-ram-write-protected-p state) mapper4-prg-ram-write-protected-p
          (cartridge-mapper4-state-mapper4-irq-latch state) mapper4-irq-latch
          (cartridge-mapper4-state-mapper4-irq-counter state) mapper4-irq-counter
          (cartridge-mapper4-state-mapper4-irq-reload-p state) mapper4-irq-reload-p
          (cartridge-mapper4-state-mapper4-irq-enabled-p state) mapper4-irq-enabled-p
          (cartridge-mapper4-state-mapper4-irq-pending-p state) mapper4-irq-pending-p
          (cartridge-mapper4-state-mapper4-ppu-a12-high-p state) mapper4-ppu-a12-high-p
          (cartridge-mapper4-state-mapper4-ppu-a12-low-cycles state) mapper4-ppu-a12-low-cycles)
    state))

(defun %make-cartridge (&key (prg-rom #()) (chr-rom #()) (mapper 0)
                             (mirroring :horizontal)
                             (battery-backed-p nil) (four-screen-p nil)
                             (chr-writable-p nil) (prg-ram #())
                             (submapper 0)
                             (bus-conflict-p nil)
                             (prg-bank 0) (chr-bank 0)
                             (initial-mirroring :horizontal)
                             (mapper5-state (%make-cartridge-mapper5-state))
                             (mapper4-state (%make-cartridge-mapper4-state))
                             (mapper-state (%make-cartridge-mapper-state))
                             (cpu-clock-required-p nil))
  (let ((cartridge (%make-cartridge-instance)))
    (set-cartridge-prg-rom! cartridge prg-rom)
    (set-cartridge-chr-rom! cartridge chr-rom)
    (set-cartridge-prg-ram! cartridge prg-ram)
    (set-cartridge-battery-dirty-p! cartridge nil)
    (set-cartridge-mapper! cartridge mapper)
    (set-cartridge-submapper! cartridge submapper)
    (set-cartridge-bus-conflict-p! cartridge bus-conflict-p)
    (set-cartridge-mirroring! cartridge mirroring)
    (set-cartridge-initial-mirroring! cartridge initial-mirroring)
    (set-cartridge-battery-backed-p! cartridge battery-backed-p)
    (set-cartridge-four-screen-p! cartridge four-screen-p)
    (set-cartridge-chr-writable-p! cartridge chr-writable-p)
    (set-cartridge-prg-bank! cartridge prg-bank)
    (set-cartridge-chr-bank! cartridge chr-bank)
    (set-cartridge-mapper5-state! cartridge mapper5-state)
    (set-cartridge-mapper4-state! cartridge mapper4-state)
    (set-cartridge-mapper-state! cartridge mapper-state)
    (set-cartridge-cpu-clock-required-p! cartridge cpu-clock-required-p)
    cartridge))
