(in-package #:cl-nes)

(define-cartridge-prg-register-writers
  (%mapper2-write-prg-register! (cartridge value)
    (let ((switchable-bank-count
            (1- (floor (length (cartridge-prg-rom cartridge))
                       +prg-bank-size+))))
      (setf (cartridge-prg-bank cartridge)
            (mod value switchable-bank-count))))

  (%mapper3-write-prg-register! (cartridge value)
    (let ((chr-bank-count (floor (length (cartridge-chr-rom cartridge))
                                 +chr-bank-size+)))
      (setf (cartridge-chr-bank cartridge)
            (mod value chr-bank-count))))

  (%mapper7-write-prg-register! (cartridge value)
    (setf (cartridge-prg-bank cartridge) (logand value #x07)
          (cartridge-mirroring cartridge)
          (if (logbitp 4 value)
              :single-screen-upper
              :single-screen-lower)))

  (%mapper11-write-prg-register! (cartridge value)
    (setf (cartridge-prg-bank cartridge) (logand value #x03)
          (cartridge-chr-bank cartridge) (ldb (byte 4 4) value)))

  (%mapper34-write-prg-register! (cartridge value)
    (setf (cartridge-prg-bank cartridge) value)))

(define-cartridge-prg-register-dispatch
    %cartridge-write-prg-register! (cartridge address value)
  (1 %when-cartridge-standard-prg-register-address
     (%mapper1-write! cartridge address value))
  (2 %when-cartridge-standard-prg-register-address
     (%mapper2-write-prg-register! cartridge value))
  (3 %when-cartridge-standard-prg-register-address
     (%mapper3-write-prg-register! cartridge value))
  (4 %when-cartridge-standard-prg-register-address
     (%mapper4-write! cartridge address value))
  (5 %when-cartridge-standard-prg-register-address
     (%mapper5-write-mapped-prg! cartridge address value))
  (7 %when-cartridge-standard-prg-register-address
     (%mapper7-write-prg-register! cartridge value))
  (11 %when-cartridge-standard-prg-register-address
      (%mapper11-write-prg-register! cartridge value))
  (22 %when-cartridge-standard-prg-register-address
      (%mapper22-write! cartridge address value))
  (28 %when-cartridge-mapper28-register-address
      (%mapper28-write! cartridge address value))
  (34 %when-cartridge-standard-prg-register-address
      (%mapper34-write-prg-register! cartridge value)))
