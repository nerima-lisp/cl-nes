(in-package #:cl-nes)

(defun %mapper4-clock-irq! (cartridge)
  (let ((counter (cartridge-mapper4-irq-counter cartridge))
        (reload-p (cartridge-mapper4-irq-reload-p cartridge)))
    (setf (cartridge-mapper4-irq-counter cartridge)
          (if (or reload-p (zerop counter))
              (cartridge-mapper4-irq-latch cartridge)
              (1- counter)))
    (setf (cartridge-mapper4-irq-reload-p cartridge) nil)
    (when (and (zerop (cartridge-mapper4-irq-counter cartridge))
               (cartridge-mapper4-irq-enabled-p cartridge))
      ;; MMC6 suppresses a second IRQ when a counter that already reached zero
      ;; is reloaded from zero.  The iNES header has no revision/submapper bit
      ;; for this distinction, so MMC6 behavior is an explicit cartridge option.
      (when (or (not (member (cartridge-mapper4-variant cartridge)
                             '(:mmc3-rev-a :mmc6 :mmc3-alt)))
                reload-p
                (plusp counter))
        (setf (cartridge-mapper4-irq-pending-p cartridge) t)))))

(defun %mapper4-clock-cpu! (cartridge cycles)
  (when (and (not (cartridge-mapper4-ppu-a12-high-p cartridge))
             (plusp cycles))
    (incf (cartridge-mapper4-a12-low-m2-cycles cartridge) cycles)))

(defun cartridge-clock-ppu-a12! (cartridge high-p)
  (when cartridge
    (when (= (cartridge-mapper cartridge) 1)
      (%mapper1-clock-ppu-a12! cartridge high-p))
    (when (= (cartridge-mapper cartridge) 4)
      (when (and high-p
                 (not (cartridge-mapper4-ppu-a12-high-p cartridge))
                 (>= (cartridge-mapper4-a12-low-m2-cycles cartridge)
                     +mapper4-a12-low-filter-cycles+))
        (%mapper4-clock-irq! cartridge))
      (setf (cartridge-mapper4-ppu-a12-high-p cartridge) high-p)
      (when high-p
        (setf (cartridge-mapper4-a12-low-m2-cycles cartridge) 0))))
  cartridge)

(defun %mapper4-write! (cartridge address value)
  (case (logand address #xE001)
    (#x8000 (setf (cartridge-mapper4-bank-select cartridge) value))
    (#x8001
     (setf (aref (cartridge-mapper4-registers cartridge)
                 (logand (cartridge-mapper4-bank-select cartridge) 7))
           value))
    (#xA000
     (unless (cartridge-four-screen-p cartridge)
       (set-cartridge-mirroring!
        cartridge
        (if (zerop (logand value 1)) :vertical :horizontal))))
    (#xA001
     (setf (cartridge-mapper4-prg-ram-enabled-p cartridge) (logbitp 7 value))
     (setf (cartridge-mapper4-prg-ram-write-protected-p cartridge) (logbitp 6 value)))
    (#xC000 (setf (cartridge-mapper4-irq-latch cartridge) value))
    (#xC001 (setf (cartridge-mapper4-irq-reload-p cartridge) t))
    (#xE000
     (setf (cartridge-mapper4-irq-enabled-p cartridge) nil)
     (setf (cartridge-mapper4-irq-pending-p cartridge) nil))
    (#xE001 (setf (cartridge-mapper4-irq-enabled-p cartridge) t)))
  value)
