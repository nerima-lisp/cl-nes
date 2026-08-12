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
  (let ((mapper (cartridge-mapper cartridge)))
    (setf (cartridge-mirroring cartridge)
          (cartridge-initial-mirroring cartridge)
          (cartridge-prg-bank cartridge) 0
          (cartridge-chr-bank cartridge) 0
          (cartridge-mapper-shift cartridge) #x10
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
          (cartridge-mapper5-prg-mode cartridge) 3
          (cartridge-mapper5-chr-mode cartridge) 3
          (cartridge-mapper5-prg-ram-protect-1 cartridge) 0
          (cartridge-mapper5-prg-ram-protect-2 cartridge) 0
          (cartridge-mapper5-exram-mode cartridge) 0
          (cartridge-mapper5-nametable-mapping cartridge) 0
          (cartridge-mapper5-fill-tile cartridge) 0
          (cartridge-mapper5-fill-attribute cartridge) 0
          (cartridge-mapper5-split-control cartridge) 0
          (cartridge-mapper5-split-scroll cartridge) 0
          (cartridge-mapper5-split-bank cartridge) 0
          (cartridge-mapper5-irq-scanline cartridge) 0
          (cartridge-mapper5-irq-enabled-p cartridge) nil
          (cartridge-mapper5-irq-pending-p cartridge) nil
          (cartridge-mapper5-in-frame-p cartridge) nil
          (cartridge-mapper5-multiplier-a cartridge) 0
          (cartridge-mapper5-multiplier-b cartridge) 0)
    (fill (cartridge-mapper-registers cartridge) 0)
    (fill (cartridge-mapper4-registers cartridge) 0)
    (fill (cartridge-mapper5-chr-banks cartridge) 0)
    (when (= mapper 5)
      (%reset-mapper5-prg-banks! cartridge)))
  cartridge)
