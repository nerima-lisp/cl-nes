(in-package #:cl-nes)

(defun %mapper4-prg-offset (cartridge address)
  (let* ((offset (- address #x8000))
         (slot (floor offset +prg-bank-8k-size+))
         (registers (cartridge-mapper4-registers cartridge))
         (bank-count (floor (length (cartridge-prg-rom cartridge))
                            +prg-bank-8k-size+))
         (last-bank (1- bank-count))
         (second-last-bank (max 0 (- last-bank 1)))
         (bank
           (if (zerop (logand (cartridge-mapper4-bank-select cartridge) #x40))
               (case slot
                 (0 (aref registers 6))
                 (1 (aref registers 7))
                 (2 second-last-bank)
                 (otherwise last-bank))
               (case slot
                 (0 second-last-bank)
                 (1 (aref registers 7))
                 (2 (aref registers 6))
                 (otherwise last-bank)))))
    (+ (* (mod bank bank-count) +prg-bank-8k-size+)
       (mod offset +prg-bank-8k-size+))))

(defun %mapper4-chr-offset (cartridge address)
  (let* ((slot (floor address +chr-bank-1k-size+))
         (registers (cartridge-mapper4-registers cartridge))
         (bank
           (if (zerop (logand (cartridge-mapper4-bank-select cartridge) #x80))
               (case slot
                 ((0 1) (+ (logand (aref registers 0) #xFE) slot))
                 ((2 3) (+ (logand (aref registers 1) #xFE)
                           (- slot 2)))
                 (4 (aref registers 2))
                 (5 (aref registers 3))
                 (6 (aref registers 4))
                 (otherwise (aref registers 5)))
               (case slot
                 (0 (aref registers 2))
                 (1 (aref registers 3))
                 (2 (aref registers 4))
                 (3 (aref registers 5))
                 ((4 5) (+ (logand (aref registers 0) #xFE)
                           (- slot 4)))
                 (otherwise (+ (logand (aref registers 1) #xFE)
                               (- slot 6)))))))
    (+ (* bank +chr-bank-1k-size+)
       (mod address +chr-bank-1k-size+))))

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
      ;; is reloaded from zero.  The iNES header has no revision/submapper bit
      ;; for this distinction, so MMC6 behavior is an explicit cartridge option.
      (when (or (not (eq (cartridge-mapper4-variant cartridge) :mmc6))
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

(defun %mapper4-write! (cartridge address value)
  (case (logand address #xE001)
    (#x8000 (setf (cartridge-mapper4-bank-select cartridge) value))
    (#x8001
     (setf (aref (cartridge-mapper4-registers cartridge)
                 (logand (cartridge-mapper4-bank-select cartridge) 7))
           value))
    (#xA000
     (unless (cartridge-four-screen-p cartridge)
       (setf (cartridge-mirroring cartridge)
             (if (zerop (logand value 1)) :vertical :horizontal))))
    (#xA001
     (setf (cartridge-mapper4-prg-ram-enabled-p cartridge)
           (logbitp 7 value)
           (cartridge-mapper4-prg-ram-write-protected-p cartridge)
           (logbitp 6 value)))
    (#xC000 (setf (cartridge-mapper4-irq-latch cartridge) value))
    (#xC001 (setf (cartridge-mapper4-irq-reload-p cartridge) t))
    (#xE000
     (setf (cartridge-mapper4-irq-enabled-p cartridge) nil
           (cartridge-mapper4-irq-pending-p cartridge) nil))
    (#xE001 (setf (cartridge-mapper4-irq-enabled-p cartridge) t)))
  value)


