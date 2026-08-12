(in-package #:cl-nes/test)

(defmacro write-prg-registers (cartridge &body writes)
  `(progn
     ,@(loop for (address value) in writes
             collect `(cartridge-write-prg! ,cartridge ,address ,value))))

(defmacro serial-write-mmc1-register (cartridge address value)
  `(dotimes (bit 5)
     (cartridge-write-prg!
      ,cartridge ,address (ldb (byte 1 bit) ,value))))

(defmacro write-mapper28-register (cartridge register value)
  `(progn
     (cartridge-write-prg! ,cartridge #x5000 ,register)
     (cartridge-write-prg! ,cartridge #x8000 ,value)))

(defmacro write-ppu-registers (ppu &body writes)
  `(progn
     ,@(loop for (address value) in writes
             collect `(ppu-write-register! ,ppu ,address ,value))))

(defmacro set-ppu-vram-address (ppu address)
  (let ((address-var (gensym "ADDRESS-")))
    `(let ((,address-var ,address))
       (write-ppu-registers ,ppu
         (6 (ldb (byte 8 8) ,address-var))
         (6 (ldb (byte 8 0) ,address-var))))))

(defmacro write-apu-registers (apu &body writes)
  `(progn
     ,@(loop for (address value) in writes
             collect `(apu-write-register! ,apu ,address ,value))))

(defmacro write-vram-values (ppu &body writes)
  `(progn
     ,@(loop for (address value) in writes
             collect `(ppu-write-vram! ,ppu ,address ,value))))

(defmacro write-oam-values (ppu &body writes)
  `(progn
     ,@(loop for (index value) in writes
             collect `(setf (aref (ppu-oam ,ppu) ,index) ,value))))

(defmacro write-expansion-registers (cartridge &body writes)
  `(progn
     ,@(loop for (address value) in writes
             collect `(cl-nes::cartridge-write-expansion!
                       ,cartridge
                       ,address
                       ,value))))

(defmacro configure-mmc5-prg-banks (cartridge mode)
  `(progn
     (write-expansion-registers ,cartridge
       (#x5100 ,mode))
     (case ,mode
       (0 (write-expansion-registers ,cartridge
            (#x5117 #x84)))
       (1 (write-expansion-registers ,cartridge
            (#x5115 #x88)
            (#x5117 #x8C)))
       (2 (write-expansion-registers ,cartridge
            (#x5115 #x82)
            (#x5116 #x8A)
            (#x5117 #x8E)))
       (3 (write-expansion-registers ,cartridge
            (#x5114 #x84)
            (#x5115 #x85)
            (#x5116 #x86)
            (#x5117 #x87))))))

(defmacro define-mmc5-prg-slot-spec (description cases)
  `(it-each ,cases
       ,description
       (mode expected-0 expected-1 expected-2 expected-3)
     (with-mmc5-cartridge (cartridge)
       (configure-mmc5-prg-banks cartridge mode)
       (expect-prg-slot-banks cartridge
                              (list expected-0 expected-1
                                    expected-2 expected-3)))))

(defmacro initialize-mmc5-chr-bank-registers (cartridge)
  `(dotimes (index 12)
     (cl-nes::cartridge-write-expansion!
      ,cartridge (+ #x5120 index) index)))

(defmacro configure-mmc5-chr-banks (cartridge mode)
  `(progn
     (case ,mode
       (0
        (write-expansion-registers ,cartridge
          (#x5127 8)
          (#x512B 0)))
       (1
        (write-expansion-registers ,cartridge
          (#x5123 4)
          (#x5127 8)
          (#x512B 0)))
       (2
        (write-expansion-registers ,cartridge
          (#x5122 0)
          (#x5124 2)
          (#x5126 4)
          (#x5127 6)
          (#x512A 8)
          (#x512B 10))))
     (write-expansion-registers ,cartridge
       (#x5101 ,mode))))

(defmacro define-mmc5-chr-slot-spec (description cases)
  `(it-each ,cases
       ,description
       (mode sprite-banks background-banks)
     (with-mmc5-cartridge (cartridge)
       (initialize-mmc5-chr-bank-registers cartridge)
       (configure-mmc5-chr-banks cartridge mode)
       (expect-mmc5-chr-slot-banks
        cartridge sprite-banks background-banks))))

(defmacro configure-mmc3-prg-banks (cartridge)
  `(write-prg-registers ,cartridge
     (#x8000 6)
     (#x8001 2)
     (#x8000 7)
     (#x8001 3)))

(defmacro configure-mmc3-chr-banks (cartridge)
  `(write-prg-registers ,cartridge
     (#x8000 0)
     (#x8001 2)
     (#x8000 1)
     (#x8001 4)
     (#x8000 2)
     (#x8001 5)
     (#x8000 3)
     (#x8001 6)
     (#x8000 4)
     (#x8001 7)
     (#x8000 5)
     (#x8001 1)))
