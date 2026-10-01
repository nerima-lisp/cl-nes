(in-package #:cl-nes)

(defun %cartridge-prg-address-p (cartridge address)
  (or (and (= (cartridge-mapper cartridge) 69)
           (<= #x6000 address #x7FFF)
           (%mapper69-prg-rom-at-6000-p cartridge))
      (and (%nrom-368-p cartridge)
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
      ((7 11 34 66 87) (%banked-32k-prg-offset cartridge address))
      (69 (%mapper69-prg-offset cartridge address))
      (79 (%mapper79-prg-offset cartridge address))
      (71 (%mapper71-prg-offset cartridge address))
      (9 (%mapper9-prg-offset cartridge address))
      (10 (%mapper10-prg-offset cartridge address))
      (22 (%mapper22-prg-offset cartridge address))
      (28 (%mapper28-prg-offset cartridge address)))))

(defun %cartridge-prg-write-address-p (cartridge address)
  (cond
    ((and (%mapper34-nina-p cartridge)
          (<= #x7FFD address #x7FFF)) t)
    ((= (cartridge-mapper cartridge) 79) (= address #x4100))
    ((= (cartridge-mapper cartridge) 28)
     (or (<= #x5000 address #x5FFF)
         (<= #x8000 address #xFFFF)))
    (t (<= #x8000 address #xFFFF))))

(defun %cartridge-bus-conflict-value (cartridge address value)
  (logand value (cartridge-read-prg cartridge address)))

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
                             (mod (logand value #x03) chr-bank-count))))

(defun %write-cartridge-mapper7-prg! (cartridge value)
  (set-cartridge-prg-bank! cartridge (logand value #x07))
  (set-cartridge-mirroring!
   cartridge
   (if (logbitp 4 value) :single-screen-upper :single-screen-lower)))

(defun %write-cartridge-mapper11-prg! (cartridge value)
  (set-cartridge-prg-bank! cartridge (logand value #x03))
  (set-cartridge-chr-bank! cartridge (ldb (byte 4 4) value)))

(defun %write-cartridge-mapper66-prg! (cartridge value)
  (let ((prg-bank-count (floor (length (cartridge-prg-rom cartridge))
                               (* 2 +prg-bank-size+)))
        (chr-bank-count (floor (length (cartridge-chr-rom cartridge))
                               +chr-bank-size+)))
    (set-cartridge-prg-bank! cartridge
                             (mod (ldb (byte 2 4) value) prg-bank-count))
    (set-cartridge-chr-bank! cartridge
                             (mod (logand value #x03) chr-bank-count))))

(defun %write-cartridge-mapper71-prg! (cartridge address value)
  (if (and (= (cartridge-submapper cartridge) 1)
           (<= #x9000 address #x9FFF))
      (set-cartridge-mirroring!
       cartridge
       (if (logbitp 4 value) :single-screen-upper :single-screen-lower))
      (let ((switchable-bank-count
              (1- (floor (length (cartridge-prg-rom cartridge))
                         +prg-bank-size+))))
        (set-cartridge-prg-bank! cartridge
                                 (mod value switchable-bank-count)))))

(defun %cartridge-prg-ram-offset (cartridge address)
  (case (cartridge-mapper cartridge)
    (69 (%mapper69-prg-ram-offset cartridge address))
    (4 (if (eq (cartridge-mapper4-variant cartridge) :mmc6)
           (mod (- address #x7000) #x400)
           (and (cartridge-mapper4-prg-ram-enabled-p cartridge)
                (- address #x6000))))
    (5 (%mapper5-prg-ram-offset cartridge address))
    (otherwise (- address #x6000))))

(defun %mapper4-mmc6-prg-ram-readable-p (cartridge address)
  (let ((offset (mod (- address #x7000) #x400)))
    (logbitp (if (< offset #x200) 5 7)
             (cartridge-mapper4-mmc6-prg-ram-protect cartridge))))

(defun %cartridge-prg-ram-writable-p (cartridge address)
  (case (cartridge-mapper cartridge)
    (1 (%mapper1-prg-ram-enabled-p cartridge))
    (69 (%mapper69-prg-ram-enabled-p cartridge))
    (4 (if (eq (cartridge-mapper4-variant cartridge) :mmc6)
           (let ((offset (mod (- address #x7000)
                              #x400)))
             (or (<= #x6000 address #x6003)
                 (and (%mapper4-mmc6-prg-ram-readable-p cartridge address)
                      (logbitp (if (< offset #x200) 4 6)
                               (cartridge-mapper4-mmc6-prg-ram-protect cartridge)))))
           (and (cartridge-mapper4-prg-ram-enabled-p cartridge)
                (not (cartridge-mapper4-prg-ram-write-protected-p cartridge)))))
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

(defun cartridge-write-prg! (cartridge address value &optional cpu-cycle)
  (when (%cartridge-prg-write-address-p cartridge address)
    (let ((value (if (and (cartridge-bus-conflict-p cartridge)
                          (member (cartridge-mapper cartridge) '(2 3 7 11)))
                     (%cartridge-bus-conflict-value cartridge address value)
                     value)))
      (case (cartridge-mapper cartridge)
        (1 (%mapper1-write! cartridge address value cpu-cycle))
        (2 (%write-cartridge-mapper2-prg! cartridge value))
        (3 (%write-cartridge-mapper3-prg! cartridge value))
        (4 (%mapper4-write! cartridge address value))
        (5 (%mapper5-write-mapped-prg! cartridge address value))
        (7 (%write-cartridge-mapper7-prg! cartridge value))
        (11 (%write-cartridge-mapper11-prg! cartridge value))
        (66 (%write-cartridge-mapper66-prg! cartridge value))
        (71 (%write-cartridge-mapper71-prg! cartridge address value))
        (69 (%mapper69-write! cartridge address value))
        (79 (%mapper79-write! cartridge value))
        (22 (%mapper22-write! cartridge address value))
        (28 (%mapper28-write! cartridge address value))
        ((9 10) (%mapper9-10-write! cartridge address value))
        (34
         (if (%mapper34-nina-p cartridge)
             (let ((chr-bank-count (floor (length (cartridge-chr-rom cartridge))
                                          +chr-bank-4k-size+)))
               (case address
                 (#x7FFD
                  (set-cartridge-prg-bank!
                   cartridge
                   (mod value
                        (floor (length (cartridge-prg-rom cartridge))
                               (* 2 +prg-bank-size+)))))
                 (#x7FFE
                  (setf (cartridge-mapper-chr-bank-0 cartridge)
                        (mod value chr-bank-count)))
                 (#x7FFF
                  (setf (cartridge-mapper-chr-bank-1 cartridge)
                        (mod value chr-bank-count))))
               (cartridge-write-prg-ram! cartridge address value))
             (set-cartridge-prg-bank! cartridge value))))))
  value)

(defun cartridge-read-prg-ram (cartridge address)
  (let ((mapper (cartridge-mapper cartridge)))
    (when (and (not (= mapper 87))
               (if (and (= mapper 4)
                        (eq (cartridge-mapper4-variant cartridge) :mmc6))
                   (and (<= #x6000 address #x7FFF)
                        (or (<= #x6000 address #x6003)
                            (%mapper4-mmc6-prg-ram-readable-p cartridge address)))
                   (<= #x6000 address #x7FFF))
               (plusp (length (cartridge-prg-ram cartridge)))
               (or (and (not (= mapper 1))
                        (not (= mapper 69)))
                   (and (= mapper 1)
                        (%mapper1-prg-ram-enabled-p cartridge))
                   (and (= mapper 69)
                        (%mapper69-prg-ram-enabled-p cartridge))))
    (let ((offset (%cartridge-prg-ram-offset cartridge address)))
      (when offset
        (aref (cartridge-prg-ram cartridge)
              (mod offset (length (cartridge-prg-ram cartridge)))))))))

(defun cartridge-write-prg-ram! (cartridge address value)
  (let ((mapper (cartridge-mapper cartridge)))
    (when (and (= mapper 87)
               (<= #x6000 address #x7FFF))
      (let ((chr-bank-count (floor (length (cartridge-chr-rom cartridge))
                                   +chr-bank-size+)))
        (set-cartridge-chr-bank! cartridge
                                 (mod (logior (ash (logand value #x01) 1)
                                              (ldb (byte 1 1) value))
                                      chr-bank-count))))
    (when (and (not (= mapper 87))
               (if (and (= mapper 4)
                        (eq (cartridge-mapper4-variant cartridge) :mmc6))
                   ;; Legacy MMC3 ROMs keep their result signature at $6000.
                   (<= #x6000 address #x7FFF)
                   (<= #x6000 address #x7FFF))
               (plusp (length (cartridge-prg-ram cartridge)))
               (%cartridge-prg-ram-writable-p cartridge address))
      (let ((offset (%cartridge-prg-ram-offset cartridge address)))
        (when offset
          (setf (aref (cartridge-prg-ram cartridge)
                      (mod offset (length (cartridge-prg-ram cartridge))))
                (logand value #xFF))
          (set-cartridge-battery-dirty-p!
           cartridge (and (cartridge-battery-backed-p cartridge) t)))))
  value))

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
