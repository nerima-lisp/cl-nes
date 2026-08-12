(in-package #:cl-nes)

(defun %mapper4-clock-irq! (cartridge)
  (let ((counter (cartridge-mapper4-irq-counter cartridge))
        (reload-p (cartridge-mapper4-irq-reload-p cartridge)))
    (setf (cartridge-mapper4-irq-counter cartridge)
          (if (or reload-p (zerop counter))
              (cartridge-mapper4-irq-latch cartridge)
              (1- counter))
          (cartridge-mapper4-irq-reload-p cartridge) nil)
    (when (and (zerop (cartridge-mapper4-irq-counter cartridge))
               (cartridge-mapper4-irq-enabled-p cartridge))
      ;; MMC6 suppresses a second IRQ when a counter that already reached zero
      ;; is reloaded from zero. The iNES header has no revision/submapper bit
      ;; for this distinction, so MMC6 behavior is an explicit cartridge option.
      (when (or (not (member (cartridge-mapper4-variant cartridge)
                             '(:mmc6 :mmc3-alt)))
                reload-p
                (plusp counter))
        (setf (cartridge-mapper4-irq-pending-p cartridge) t)))))

(defun cartridge-clock-ppu-a12! (cartridge high-p &optional (low-cycles 1))
  (when (and cartridge (= (cartridge-mapper cartridge) 4))
    (if high-p
        (when (and (not (cartridge-mapper4-ppu-a12-high-p cartridge))
                   (>= (cartridge-mapper4-ppu-a12-low-cycles cartridge)
                       +mapper4-a12-low-filter-cycles+))
          (%mapper4-clock-irq! cartridge))
        (incf (cartridge-mapper4-ppu-a12-low-cycles cartridge)
              (max 0 low-cycles)))
    (setf (cartridge-mapper4-ppu-a12-high-p cartridge) high-p)
    (when high-p
      (setf (cartridge-mapper4-ppu-a12-low-cycles cartridge) 0)))
  cartridge)
