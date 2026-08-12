(in-package #:cl-nes)

(defparameter +supported-mappers+ '(0 1 2 3 4 5 7 11 22 28 34))
(defparameter +supported-mapper4-variants+ '(:mmc3 :mmc6 :mmc3-alt))

(defmacro %storage-validation-spec (mapper validator reason &rest arguments)
  `(list ,mapper ',validator ,reason ,@arguments))

(defparameter +prg-storage-validation-specs+
  (list
   (%storage-validation-spec
    0 %size-one-of-p
    "NROM PRG data must be 16 KiB, 32 KiB, or 48 KiB"
    (* 16 1024) (* 32 1024) (* 48 1024))
   (%storage-validation-spec
    1 %banked-size-p
    "MMC1 PRG data must use 16 KiB banks"
    (* 16 1024) +prg-bank-size+)
   (%storage-validation-spec
    2 %banked-size-p
    "UxROM PRG data must have at least two 16 KiB banks"
    (* 32 1024) +prg-bank-size+)
   (%storage-validation-spec
    3 %size-one-of-p
    "CNROM PRG data must be 16 KiB or 32 KiB"
    (* 16 1024) (* 32 1024))
   (%storage-validation-spec
    4 %banked-size-p
    "MMC3/MMC5 PRG data must have at least two 8 KiB banks"
    (* 2 +prg-bank-8k-size+) +prg-bank-8k-size+)
   (%storage-validation-spec
    5 %banked-size-p
    "MMC3/MMC5 PRG data must have at least two 8 KiB banks"
    (* 2 +prg-bank-8k-size+) +prg-bank-8k-size+)
   (%storage-validation-spec
    7 %banked-size-p
    "AxROM PRG data must use 16 KiB units"
    1 +prg-bank-size+)
   (%storage-validation-spec
    11 %banked-size-p
    "32 KiB banked PRG data is required"
    (* 32 1024) (* 32 1024))
   (%storage-validation-spec
    22 %banked-size-p
    "VRC2 PRG data must use 8 KiB units"
    +prg-bank-size+ +prg-bank-8k-size+)
   (%storage-validation-spec
    28 %banked-size-p
    "Action 53 PRG data must use 16 KiB units"
    1 +prg-bank-size+)
   (%storage-validation-spec
    34 %banked-size-p
    "32 KiB banked PRG data is required"
    (* 32 1024) (* 32 1024))))

(defparameter +chr-storage-validation-specs+
  (list
   (%storage-validation-spec
    0 %exact-size-p
    "CHR storage size is not supported by this mapper"
    +chr-bank-size+)
   (%storage-validation-spec
    1 %banked-size-p
    "CHR storage size is not supported by this mapper"
    +chr-bank-size+ +chr-bank-size+)
   (%storage-validation-spec
    2 %exact-size-p
    "CHR storage size is not supported by this mapper"
    +chr-bank-size+)
   (%storage-validation-spec
    3 %banked-size-p
    "CHR storage size is not supported by this mapper"
    +chr-bank-size+ +chr-bank-size+)
   (%storage-validation-spec
    4 %banked-size-p
    "CHR storage size is not supported by this mapper"
    1 +chr-bank-1k-size+)
   (%storage-validation-spec
    5 %banked-size-p
    "CHR storage size is not supported by this mapper"
    1 +chr-bank-1k-size+)
   (%storage-validation-spec
    7 %exact-size-p
    "CHR storage size is not supported by this mapper"
    +chr-bank-size+)
   (%storage-validation-spec
    11 %banked-size-p
    "CHR storage size is not supported by this mapper"
    +chr-bank-size+ +chr-bank-size+)
   (%storage-validation-spec
    22 %banked-size-p
    "CHR storage size is not supported by this mapper"
    1 +chr-bank-1k-size+)
   (%storage-validation-spec
    28 %banked-size-p
    "CHR storage size is not supported by this mapper"
    +chr-bank-size+ +chr-bank-size+)
   (%storage-validation-spec
    34 %exact-size-p
    "CHR storage size is not supported by this mapper"
    +chr-bank-size+)))
