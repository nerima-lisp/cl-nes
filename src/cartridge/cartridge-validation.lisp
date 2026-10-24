(in-package #:cl-nes)

(defun %ensure-supported-mapper! (mapper)
  (unless (member mapper '(0 1 2 3 4 5 7 9 10 11 22 28 30 34 66 69 71 79 87 113))
    (error 'unsupported-mapper :number mapper)))

(defun %ensure-valid-mapper4-variant! (mapper4-variant)
  (unless (member mapper4-variant '(:mmc3 :mmc3-rev-a :mmc6 :mmc3-alt))
    (error 'invalid-rom
           :reason "MMC3 variant must be :MMC3, :MMC3-REV-A, :MMC6, or :MMC3-ALT")))
(defun %ensure-valid-mapper30-submapper! (mapper submapper)
  (when (and (= mapper 30)
             (not (member submapper (list 0 1 2 3 4))))
    (error (quote invalid-rom)
           :reason "Mapper 30 submapper must be 0, 1, 2, 3, or 4")))
(defun %ensure-mapper30-chr-ram! (mapper chr-writable-p)
  (when (and (= mapper 30)
             (not chr-writable-p))
    (error (quote invalid-rom)
           :reason "Mapper 30 requires CHR-RAM")))
(defun %ensure-mapper-has-no-prg-ram! (mapper prg-ram-size)
  (when (and (member mapper (list 30 113))
             (plusp prg-ram-size))
    (error (quote invalid-rom)
           :reason "Mapper 30 and 113 do not support PRG-RAM")))

(defun %ensure-valid-prg-ram-size! (prg-ram-size)
  (unless (and (integerp prg-ram-size) (>= prg-ram-size 0))
    (error 'invalid-rom :reason "PRG-RAM size must be a non-negative integer")))

(defun %default-chr-rom (mapper)
  (make-array (case mapper
                ((28 30) (* 4 +chr-bank-size+))
                (otherwise +chr-bank-size+))
              :element-type '(unsigned-byte 8)
              :initial-element 0))

(defun %ensure-action53-prg-layout! (prg)
  (unless (and (plusp (length prg))
               (zerop (mod (length prg) +prg-bank-size+)))
    (error 'invalid-rom :reason "Action 53 PRG data must use 16 KiB units")))

(defun %ensure-nrom-prg-layout! (prg)
  (unless (member (length prg)
                  (list (* 16 1024) (* 32 1024) (* 48 1024)))
    (error 'invalid-rom
           :reason "NROM PRG data must be 16 KiB, 32 KiB, or 48 KiB")))

(defun %ensure-uxrom-prg-layout! (prg)
  (unless (and (>= (length prg) (* 32 1024))
               (zerop (mod (length prg) +prg-bank-size+)))
    (error 'invalid-rom
           :reason "UxROM PRG data must have at least two 16 KiB banks")))

(defun %ensure-mmc1-prg-layout! (prg)
  (unless (and (>= (length prg) (* 16 1024))
               (zerop (mod (length prg) +prg-bank-size+)))
    (error 'invalid-rom :reason "MMC1 PRG data must use 16 KiB banks")))

(defun %ensure-cnrom-prg-layout! (prg)
  (unless (member (length prg) (list (* 16 1024) (* 32 1024)))
    (error 'invalid-rom :reason "CNROM PRG data must be 16 KiB or 32 KiB")))

(defun %ensure-axrom-prg-layout! (prg)
  (unless (and (plusp (length prg))
               (zerop (mod (length prg) +prg-bank-size+)))
    (error 'invalid-rom :reason "AxROM PRG data must use 16 KiB units")))

(defun %ensure-32k-banked-prg-layout! (prg)
  (unless (and (>= (length prg) (* 32 1024))
               (zerop (mod (length prg) (* 32 1024))))
    (error 'invalid-rom :reason "32 KiB banked PRG data is required")))

(defun %ensure-mapper30-prg-layout! (prg)
  (unless (and (<= (* 2 +prg-bank-size+)
                   (length prg)
                   (* 32 +prg-bank-size+))
               (zerop (mod (length prg) +prg-bank-size+)))
    (error 'invalid-rom
           :reason "Mapper 30 PRG data must use 16 KiB banks up to 512 KiB")))

(defun %ensure-mapper113-prg-layout! (prg)
  (unless (and (<= (* 2 +prg-bank-size+)
                   (length prg)
                   (* 8 2 +prg-bank-size+))
               (zerop (mod (length prg) (* 2 +prg-bank-size+))))
    (error 'invalid-rom
           :reason "Mapper 113 PRG data must use 32 KiB banks up to 256 KiB")))

(defun %ensure-vrc2-prg-layout! (prg)
  (unless (and (>= (length prg) +prg-bank-size+)
               (zerop (mod (length prg) +prg-bank-8k-size+)))
    (error 'invalid-rom :reason "VRC2 PRG data must use 8 KiB units")))

(defun %ensure-mmc3/mmc5-prg-layout! (prg)
  (unless (and (>= (length prg) (* 2 +prg-bank-8k-size+))
               (zerop (mod (length prg) +prg-bank-8k-size+)))
    (error 'invalid-rom
           :reason "MMC3/MMC5 PRG data must have at least two 8 KiB banks")))

(defun %ensure-mmc2-prg-layout! (prg)
  (unless (and (>= (length prg) (* 4 +prg-bank-8k-size+))
               (zerop (mod (length prg) +prg-bank-8k-size+)))
    (error 'invalid-rom
           :reason "MMC2 PRG data must have at least four 8 KiB banks")))

(defun %ensure-mmc4-prg-layout! (prg)
  (unless (and (>= (length prg) +prg-bank-size+)
               (zerop (mod (length prg) +prg-bank-size+)))
    (error 'invalid-rom :reason "MMC4 PRG data must use 16 KiB banks")))

(defun %ensure-valid-prg-layout! (mapper prg)
  (when (= mapper 28)
    (%ensure-action53-prg-layout! prg))
  (cond
    ((= mapper 0) (%ensure-nrom-prg-layout! prg))
    ((= mapper 2) (%ensure-uxrom-prg-layout! prg))
    ((= mapper 1) (%ensure-mmc1-prg-layout! prg))
    ((= mapper 3) (%ensure-cnrom-prg-layout! prg))
    ((= mapper 7) (%ensure-axrom-prg-layout! prg))
    ((= mapper 30) (%ensure-mapper30-prg-layout! prg))
    ((= mapper 113) (%ensure-mapper113-prg-layout! prg))
    ((member mapper '(11 34 66 87)) (%ensure-32k-banked-prg-layout! prg))
    ((= mapper 71) (%ensure-uxrom-prg-layout! prg))
    ((= mapper 69) (%ensure-valid-prg-layout! 4 prg))
    ((= mapper 79) (%ensure-32k-banked-prg-layout! prg))
    ((= mapper 22) (%ensure-vrc2-prg-layout! prg))
    ((member mapper '(4 5)) (%ensure-mmc3/mmc5-prg-layout! prg))
    ((= mapper 9) (%ensure-mmc2-prg-layout! prg))
    ((= mapper 10) (%ensure-mmc4-prg-layout! prg))))

(defun %ensure-valid-chr-layout! (mapper chr)
  (unless (case mapper
            (30 (member (length chr)
                        (list +chr-bank-size+
                              (* 2 +chr-bank-size+)
                              (* 4 +chr-bank-size+))))
            (113 (and (<= +chr-bank-size+ (length chr)
                          (* 16 +chr-bank-size+))
                      (zerop (mod (length chr) +chr-bank-size+))))
            (22 (and (plusp (length chr))
                     (zerop (mod (length chr) +chr-bank-1k-size+))))
            (3 (and (<= +chr-bank-size+ (length chr) (* 4 +chr-bank-size+))
                     (zerop (mod (length chr) +chr-bank-size+))))
            (34 (if (> (length chr) +chr-bank-size+)
                    (zerop (mod (length chr) +chr-bank-4k-size+))
                    (= (length chr) +chr-bank-size+)))
            ((1 11 28 66 69 79 87) (and (>= (length chr) +chr-bank-size+)
                                         (zerop (mod (length chr) +chr-bank-size+))))
            ((4 5) (and (plusp (length chr))
                        (zerop (mod (length chr) +chr-bank-1k-size+))))
            ((9 10) (and (plusp (length chr))
                         (zerop (mod (length chr) +chr-bank-4k-size+))))
            (otherwise (= (length chr) +chr-bank-size+)))
    (error 'invalid-rom
           :reason "CHR storage size is not supported by this mapper")))

(defun %initialize-mapper5-prg-banks! (mapper mapper5-prg-banks prg)
  (when (= mapper 5)
    (setf (aref mapper5-prg-banks 4) #x80
          (aref mapper5-prg-banks 5) #x80
          (aref mapper5-prg-banks 6) #x80
          (aref mapper5-prg-banks 7)
          (logior #x80
                  (1- (floor (length prg) +prg-bank-8k-size+))))))
