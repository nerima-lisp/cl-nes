(in-package #:cl-nes)

(defun %cartridge-nrom-368-p (cartridge)
  (and cartridge
       (= (cartridge-mapper cartridge) 0)
       (= (length (cartridge-prg-rom cartridge)) (* 48 1024))))

(defun %cartridge-prg-read-offset (cartridge address)
  (let* ((mapper (cartridge-mapper cartridge))
         (rom (cartridge-prg-rom cartridge))
         (nrom368-p (%cartridge-nrom-368-p cartridge)))
    (mod
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
       (22 (%mapper22-prg-offset cartridge address))
       (28 (%mapper28-prg-offset cartridge address)))
     (length rom))))

(defun %cartridge-prg-ram-offset (cartridge address)
  (case (cartridge-mapper cartridge)
    (4
     (and (cartridge-mapper4-prg-ram-enabled-p cartridge)
          (- address #x6000)))
    (5 (%mapper5-prg-ram-offset cartridge address))
    (otherwise (- address #x6000))))

(defun %cartridge-prg-ram-writable-p (cartridge)
  (case (cartridge-mapper cartridge)
    (4
     (and (cartridge-mapper4-prg-ram-enabled-p cartridge)
          (not (cartridge-mapper4-prg-ram-write-protected-p cartridge))))
    (5 (%mapper5-prg-ram-writable-p cartridge))
    (otherwise t)))
