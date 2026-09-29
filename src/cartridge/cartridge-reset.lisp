(in-package #:cl-nes)

(defun %reset-mapper5-prg-banks! (cartridge)
  (let ((banks (cartridge-mapper5-prg-banks cartridge)))
    (fill banks 0)
    (setf (aref banks 4) #x80
          (aref banks 5) #x80
          (aref banks 6) #x80
          (aref banks 7)
          (logior #x80
                  (1- (floor (length (cartridge-prg-rom cartridge))
                             +prg-bank-8k-size+))))))

(defun cartridge-reset! (cartridge)
  "Reset mapper registers while retaining cartridge-backed RAM contents."
  (let ((mapper (cartridge-mapper cartridge))
        (mapper5-state (cartridge-mapper5-state cartridge)))
    (set-cartridge-mirroring! cartridge
                              (cartridge-initial-mirroring cartridge))
    (set-cartridge-prg-bank! cartridge 0)
    (set-cartridge-chr-bank! cartridge 0)
    (setf (cartridge-mapper-shift cartridge) #x10
          (cartridge-mapper-control cartridge) #x0C
          (cartridge-mapper-chr-bank-0 cartridge) 0
          (cartridge-mapper-chr-bank-1 cartridge) 0
          (cartridge-mapper-prg-bank-1 cartridge) 0
          (cartridge-mapper-register-select cartridge) 0
          (cartridge-mapper-mode cartridge)
          (if (= mapper 28)
              (if (eq (cartridge-initial-mirroring cartridge) :vertical)
                  #x0E
                  #x0F)
              0)
          (cartridge-mapper-outer-bank cartridge) #xFF
          (cartridge-mapper69-command cartridge) 0
          (cartridge-mapper69-irq-counter cartridge) 0
          (cartridge-mapper69-irq-enabled-p cartridge) nil
          (cartridge-mapper69-irq-pending-p cartridge) nil
          (cartridge-mapper1-last-write-cycle cartridge) nil
          (cartridge-mapper4-bank-select cartridge) 0
          (cartridge-mapper4-prg-ram-enabled-p cartridge) t
          (cartridge-mapper4-prg-ram-write-protected-p cartridge) nil
          (cartridge-mapper4-irq-latch cartridge) 0
          (cartridge-mapper4-irq-counter cartridge) 0
          (cartridge-mapper4-irq-reload-p cartridge) nil
          (cartridge-mapper4-irq-enabled-p cartridge) nil
          (cartridge-mapper4-irq-pending-p cartridge) nil
          (cartridge-mapper4-ppu-a12-high-p cartridge) nil
          (cartridge-mapper4-ppu-a12-low-cycles cartridge) 0
          (cartridge-mapper5-state-prg-mode mapper5-state) 3
          (cartridge-mapper5-state-chr-mode mapper5-state) 3
          (cartridge-mapper5-state-prg-ram-protect-1 mapper5-state) 0
          (cartridge-mapper5-state-prg-ram-protect-2 mapper5-state) 0
          (cartridge-mapper5-state-exram-mode mapper5-state) 0
          (cartridge-mapper5-state-nametable-mapping mapper5-state) 0
          (cartridge-mapper5-state-fill-tile mapper5-state) 0
          (cartridge-mapper5-state-fill-attribute mapper5-state) 0
          (cartridge-mapper5-state-split-control mapper5-state) 0
          (cartridge-mapper5-state-split-scroll mapper5-state) 0
          (cartridge-mapper5-state-split-bank mapper5-state) 0
          (cartridge-mapper5-state-irq-scanline mapper5-state) 0
          (cartridge-mapper5-state-irq-enabled-p mapper5-state) nil
          (cartridge-mapper5-state-irq-pending-p mapper5-state) nil
          (cartridge-mapper5-state-in-frame-p mapper5-state) nil
          (cartridge-mapper5-state-multiplier-a mapper5-state) 0
          (cartridge-mapper5-state-multiplier-b mapper5-state) 0)
    (fill (cartridge-mapper-registers cartridge) 0)
    (fill (cartridge-mapper69-registers cartridge) 0)
    (fill (cartridge-mapper4-registers cartridge) 0)
    (fill (cartridge-mapper5-chr-banks cartridge) 0)
    (when (= mapper 5)
      (%reset-mapper5-prg-banks! cartridge)))
  cartridge)
