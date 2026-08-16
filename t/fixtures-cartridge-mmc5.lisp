(in-package #:cl-nes/test)

(defmacro with-mmc5-cartridge ((name &rest initargs) &body body)
  "Bind NAME to a patterned MMC5 cartridge with standard test dimensions."
  `(with-patterned-cartridge (,name
                              :mapper 5
                              :prg-banks 16
                              :chr-banks 16
                              ,@initargs)
     ,@body))

(defmacro write-mmc5-registers! (cartridge &body writes)
  "Write MMC5 expansion registers from ADDRESS/VALUE pairs."
  `(progn
     ,@(loop for (address value) in writes
             collect
             `(cl-nes::cartridge-write-expansion!
               ,cartridge ,address ,value))))

(defmacro seed-mmc5-chr-banks! (cartridge count)
  "Initialize sequential MMC5 CHR bank registers from $5120."
  `(dotimes (index ,count)
     (cl-nes::cartridge-write-expansion!
      ,cartridge (+ #x5120 index) index)))

(defmacro expect-mmc5-prg-layout (cartridge expected-banks)
  "Assert the four CPU-visible MMC5 PRG slots."
  `(loop for address from #x8000 by #x2000
         for expected in ,expected-banks
         do (expect (cartridge-read-prg ,cartridge address)
                    :to-be expected)))

(defmacro expect-mmc5-chr-layout
    (cartridge sprite-banks background-banks)
  "Assert the eight MMC5 sprite/background CHR slots."
  `(loop for slot below 8
         for expected-sprite in ,sprite-banks
         for expected-background in ,background-banks
         for address = (* slot cl-nes::+chr-bank-1k-size+)
         do (expect (cartridge-read-chr ,cartridge address t)
                    :to-be expected-sprite)
            (expect (cartridge-read-chr ,cartridge address nil)
                    :to-be expected-background)))

(defmacro expect-mmc5-nametable-location
    (cartridge address expected-source expected-within)
  "Assert the decoded MMC5 nametable source for ADDRESS."
  `(multiple-value-bind (source within)
       (cl-nes::cartridge-mmc5-nametable-location ,cartridge ,address)
     (expect source :to-be ,expected-source)
     (expect within :to-be ,expected-within)))
