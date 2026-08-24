(in-package #:cl-nes)

(defun %cartridge-prg-address-p (cartridge address)
  (or (and (%nrom-368-p cartridge)
           (<= #x4800 address #xFFFF))
      (<= #x8000 address #xFFFF)))

(defun %cartridge-prg-offset (cartridge address)
  (let* ((mapper (cartridge-mapper cartridge))
         (rom (cartridge-prg-rom cartridge))
         (nrom368-p (%nrom-368-p cartridge)))
    (case mapper
      ((0 3)
       (if nrom368-p
           (- address #x4000)
           (- address #x8000)))
      (1
       (%mapper1-prg-offset cartridge address))
      (2
       (let* ((offset (- address #x8000))
              (bank-count (floor (length rom) +prg-bank-size+))
              (fixed-bank (1- bank-count)))
         (if (< offset +prg-bank-size+)
             (+ (* (mod (cartridge-prg-bank cartridge) fixed-bank)
                   +prg-bank-size+)
                offset)
             (+ (* fixed-bank +prg-bank-size+)
                (- offset +prg-bank-size+)))))
      (4 (%mapper4-prg-offset cartridge address))
      ((7 11 34) (%banked-32k-prg-offset cartridge address))
      (9 (%mapper9-prg-offset cartridge address))
      (10 (%mapper10-prg-offset cartridge address))
      (22 (%mapper22-prg-offset cartridge address))
      (28 (%mapper28-prg-offset cartridge address)))))

(defun %cartridge-prg-write-address-p (cartridge address)
  (if (= (cartridge-mapper cartridge) 28)
      (or (<= #x5000 address #x5FFF)
          (<= #x8000 address #xFFFF))
      (<= #x8000 address #xFFFF)))

(defun %write-cartridge-mapper2-prg! (cartridge value)
  (let ((switchable-bank-count
          (1- (floor (length (cartridge-prg-rom cartridge))
                     +prg-bank-size+))))
    (set-cartridge-prg-bank! cartridge
                             (mod value switchable-bank-count))))

(defun %write-cartridge-mapper3-prg! (cartridge value)
  (let ((chr-bank-count (floor (length (cartridge-chr-rom cartridge))
                               +chr-bank-size+)))
    (set-cartridge-chr-bank! cartridge
                             (mod value chr-bank-count))))

(defun %write-cartridge-mapper7-prg! (cartridge value)
  (set-cartridge-prg-bank! cartridge (logand value #x07))
  (set-cartridge-mirroring!
   cartridge
   (if (logbitp 4 value) :single-screen-upper :single-screen-lower)))

(defun %write-cartridge-mapper11-prg! (cartridge value)
  (set-cartridge-prg-bank! cartridge (logand value #x03))
  (set-cartridge-chr-bank! cartridge (ldb (byte 4 4) value)))

(defun %cartridge-prg-ram-offset (cartridge address)
  (case (cartridge-mapper cartridge)
    (4 (and (cartridge-mapper4-prg-ram-enabled-p cartridge)
            (- address #x6000)))
    (5 (%mapper5-prg-ram-offset cartridge address))
    (otherwise (- address #x6000))))

(defun %cartridge-prg-ram-writable-p (cartridge)
  (case (cartridge-mapper cartridge)
    (4 (and (cartridge-mapper4-prg-ram-enabled-p cartridge)
            (not (cartridge-mapper4-prg-ram-write-protected-p cartridge))))
    (5 (%mapper5-prg-ram-writable-p cartridge))
    (otherwise t)))

(defun cartridge-read-prg (cartridge address)
  (let ((rom (cartridge-prg-rom cartridge)))
    (when (%cartridge-prg-address-p cartridge address)
      (if (= (cartridge-mapper cartridge) 5)
          (%mapper5-read-prg cartridge address)
          (aref rom
                (mod (%cartridge-prg-offset cartridge address)
                     (length rom)))))))

(defun cartridge-write-prg! (cartridge address value)
  (when (%cartridge-prg-write-address-p cartridge address)
    (case (cartridge-mapper cartridge)
      (1 (%mapper1-write! cartridge address value))
      (2 (%write-cartridge-mapper2-prg! cartridge value))
      (3 (%write-cartridge-mapper3-prg! cartridge value))
      (4 (%mapper4-write! cartridge address value))
      (5 (%mapper5-write-mapped-prg! cartridge address value))
      (7 (%write-cartridge-mapper7-prg! cartridge value))
      (11 (%write-cartridge-mapper11-prg! cartridge value))
      (22 (%mapper22-write! cartridge address value))
      (28 (%mapper28-write! cartridge address value))
      ((9 10) (%mapper9-10-write! cartridge address value))
      (34 (set-cartridge-prg-bank! cartridge value))))
  value)

(defun cartridge-read-prg-ram (cartridge address)
  (when (and (<= #x6000 address #x7FFF)
             (plusp (length (cartridge-prg-ram cartridge))))
    (let ((offset (%cartridge-prg-ram-offset cartridge address)))
      (when offset
        (aref (cartridge-prg-ram cartridge)
              (mod offset (length (cartridge-prg-ram cartridge))))))))

(defun cartridge-write-prg-ram! (cartridge address value)
  (when (and (<= #x6000 address #x7FFF)
             (plusp (length (cartridge-prg-ram cartridge)))
             (%cartridge-prg-ram-writable-p cartridge))
    (let ((offset (%cartridge-prg-ram-offset cartridge address)))
      (when offset
        (setf (aref (cartridge-prg-ram cartridge)
                    (mod offset (length (cartridge-prg-ram cartridge))))
              (logand value #xFF)))))
  value)

(defun cartridge-read-chr (cartridge address &optional (sprite-p t))
  (when (<= 0 address #x1FFF)
    (cartridge-clock-ppu-latch! cartridge address)
    (let ((rom (cartridge-chr-rom cartridge)))
      (aref rom
            (mod (%cartridge-chr-offset cartridge address sprite-p)
                 (length rom))))))

(defun cartridge-write-chr! (cartridge address value)
  (when (and (cartridge-chr-writable-p cartridge)
             (<= 0 address #x1FFF))
    (let ((rom (cartridge-chr-rom cartridge)))
      (setf (aref rom
                  (mod (%cartridge-chr-offset cartridge address) (length rom)))
            (logand value #xFF))))
  value)
