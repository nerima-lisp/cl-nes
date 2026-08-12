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
