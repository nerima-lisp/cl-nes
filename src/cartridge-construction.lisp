(in-package #:cl-nes)

(defun %ensure-cartridge-options! (mapper mapper4-variant prg-ram-size)
  (unless (member mapper +supported-mappers+)
    (error 'unsupported-mapper :number mapper))
  (%invalid-rom-unless
   (member mapper4-variant +supported-mapper4-variants+)
   "MMC3 variant must be :MMC3, :MMC6, or :MMC3-ALT")
  (%invalid-rom-unless
   (and (integerp prg-ram-size) (>= prg-ram-size 0))
   "PRG-RAM size must be a non-negative integer"))

(defun %validate-prg-storage! (mapper prg)
  (%validate-storage-size! mapper (length prg) +prg-storage-validation-specs+))

(defun %validate-chr-storage! (mapper chr)
  (%validate-storage-size! mapper (length chr) +chr-storage-validation-specs+))
