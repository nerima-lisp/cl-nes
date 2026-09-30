(in-package #:cl-nes/test)

(defmacro with-mmc3-cartridge ((name &rest initargs) &body body)
  "Bind NAME to a patterned MMC3-family cartridge with standard test dimensions."
  `(with-patterned-cartridge (,name
                              :mapper 4
                              :prg-banks 8
                              :chr-banks 8
                              ,@initargs)
     ,@body))

(defmacro write-mmc1-registers! (cartridge &body writes)
  "Serially write MMC1 ADDRESS/VALUE pairs through the shift register."
  `(progn
     ,@(loop for (address value) in writes
             collect
             `(dotimes (bit 5)
                (cartridge-write-prg! ,cartridge
                                      ,address
                                      (ldb (byte 1 bit) ,value))))))

(defmacro expect-mmc1-prg-layout (cartridge low-bank high-bank)
  "Assert the two CPU-visible MMC1 PRG slots."
  `(progn
     (expect (cartridge-read-prg ,cartridge #x8000) :to-be ,low-bank)
     (expect (cartridge-read-prg ,cartridge #xC000) :to-be ,high-bank)))

(defmacro expect-mmc1-chr-layout (cartridge low-bank high-bank)
  "Assert the two PPU-visible MMC1 CHR slots in 4 KiB mode."
  `(progn
     (expect (cartridge-read-chr ,cartridge 0) :to-be ,low-bank)
     (expect (cartridge-read-chr ,cartridge #x1000) :to-be ,high-bank)))

(defmacro exercise-mmc1-prg-cases (cartridge &body cases)
  "Apply MMC1 register WRITES for each case and assert the resulting PRG layout."
  `(progn
     ,@(loop for (writes low-bank high-bank) in cases
             collect
             `(progn
                (write-mmc1-registers! ,cartridge
                  ,@writes)
                (expect-mmc1-prg-layout ,cartridge ,low-bank ,high-bank)))))

(defmacro write-mapper28-registers! (cartridge &body writes)
  "Write Action 53 REGISTER/VALUE pairs through the mapper 28 selector."
  `(progn
     ,@(loop for (register value) in writes
             collect
             `(progn
                (cartridge-write-prg! ,cartridge #x5000 ,register)
                (cartridge-write-prg! ,cartridge #x8000 ,value)))))

(defmacro expect-readable-prg-banks (cartridge &rest addresses)
  "Assert that each CPU-visible PRG slot returns a bank number."
  `(progn
     ,@(loop for address in addresses
             collect
             `(expect (numberp (cartridge-read-prg ,cartridge ,address))
                      :to-be t))))

(defmacro exercise-mapper28-bank-modes (cartridge modes &body writes)
  "Apply WRITES after each mapper 28 mode change and assert readable PRG slots."
  `(dolist (mode ,modes)
     (write-mapper28-registers! ,cartridge
       (#x80 mode)
       ,@writes)
     (expect-readable-prg-banks ,cartridge #x8000 #xC000)))

(defmacro seed-mmc3-prg-registers! (cartridge &body writes)
  "Initialize MMC3 bank registers from REGISTER/VALUE pairs."
  `(progn
     ,@(loop for (register value) in writes
             collect
             `(progn
                (cartridge-write-prg! ,cartridge #x8000 ,register)
                (cartridge-write-prg! ,cartridge #x8001 ,value)))))

(defmacro expect-mmc3-prg-layout (cartridge expected-banks)
  "Assert the four CPU-visible MMC3 PRG slots."
  `(loop for address from #x8000 by #x2000
         for expected in ,expected-banks
         do (expect (cartridge-read-prg ,cartridge address)
                    :to-be expected)))

(defmacro expect-mmc3-chr-layout (cartridge expected-banks)
  "Assert the eight PPU-visible MMC3 CHR slots."
  `(loop for slot below 8
         for expected in ,expected-banks
         for address = (* slot cl-nes::+chr-bank-1k-size+)
         do (expect (cartridge-read-chr ,cartridge address)
                    :to-be expected)))
