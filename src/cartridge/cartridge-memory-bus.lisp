(in-package #:cl-nes)

(defun cartridge-ppu-read-nametable (cartridge ciram address)
  (if (not (and cartridge (= (cartridge-mapper cartridge) 5)))
      (aref ciram (%mirrored-nametable-index cartridge address))
      (multiple-value-bind (source within)
          (cartridge-mmc5-nametable-location cartridge address)
        (case source
          (:ciram-0 (aref ciram within))
          (:ciram-1 (aref ciram (+ #x400 within)))
          (:exram (aref (cartridge-mapper5-state-exram
                         (cartridge-mapper5-state cartridge))
                        within))
          (:fill (cartridge-mmc5-fill-value cartridge within))))))

(defun cartridge-ppu-write-nametable! (cartridge ciram address value)
  (if (not (and cartridge (= (cartridge-mapper cartridge) 5)))
      (setf (aref ciram (%mirrored-nametable-index cartridge address)) value)
      (multiple-value-bind (source within)
          (cartridge-mmc5-nametable-location cartridge address)
        (case source
          (:ciram-0 (setf (aref ciram within) value))
          (:ciram-1 (setf (aref ciram (+ #x400 within)) value))
          (:exram (setf (aref (cartridge-mapper5-state-exram
                               (cartridge-mapper5-state cartridge))
                              within)
                        value))
          (:fill nil))))
  value)

(defun cartridge-cpu-read (cartridge address)
  (when cartridge
    (cond
      ((%cartridge-prg-address-p cartridge address)
       (cartridge-read-prg cartridge address))
      ((<= #x5000 address #x5FFF)
       (cartridge-read-expansion cartridge address))
      ((<= #x6000 address #x7FFF)
       (cartridge-read-prg-ram cartridge address))
      (t nil))))

(defun cartridge-cpu-write! (cartridge address value &optional cpu-cycle)
  (when cartridge
    (cond
      ((and (= (cartridge-mapper cartridge) 79)
            (= address #x4100))
       (cartridge-write-prg! cartridge address value))
      ((and (<= #x5000 address #x5FFF)
            (= (cartridge-mapper cartridge) 5))
       (cartridge-write-expansion! cartridge address value))
      ((<= #x5000 address #x5FFF)
       (cartridge-write-prg! cartridge address value cpu-cycle))
      ((and (<= #x6000 address #x7FFF)
            (not (%nrom-368-p cartridge)))
       (cartridge-write-prg-ram! cartridge address value))
      ((>= address #x8000)
       (cartridge-write-prg! cartridge address value cpu-cycle))
      (t nil)))
  value)
