(in-package #:cl-nes/test-runner)

(defun test-cartridge-and-ines ()
  (let* ((prg (make-array #x4000
                         :element-type '(unsigned-byte 8)
                         :initial-element #xAA))
         (cartridge (make-cartridge :prg-rom prg
                                    :chr-writable-p t))
         (rom (make-array (+ 16 #x4000 #x2000)
                          :element-type '(unsigned-byte 8)
                          :initial-element 0)))
    (check-equal (cartridge-read-prg cartridge #x8000) #xAA
                 "NROM-128 maps PRG at $8000")
    (check-equal (cartridge-read-prg cartridge #xC000) #xAA
                 "NROM-128 mirrors PRG at $C000")
    (cartridge-write-chr! cartridge 0 #x5C)
    (check-equal (cartridge-read-chr cartridge 0) #x5C
                 "CHR-RAM accepts writes")
    (setf (aref rom 0) #x4E
          (aref rom 1) #x45
          (aref rom 2) #x53
          (aref rom 3) #x1A
          (aref rom 4) 1
          (aref rom 5) 1
          (aref rom 6) 1
          (aref rom 16) #x7E)
    (let ((loaded (load-cartridge rom)))
      (check-equal (cartridge-read-prg loaded #x8000) #x7E
                   "iNES PRG payload is loaded")
      (check-equal (cartridge-mirroring loaded) :vertical
                   "iNES mirroring flag is decoded")
      (check (not (cartridge-chr-writable-p loaded))
             "iNES CHR-ROM is read-only"))
    (setf (aref rom 6) 0
          (aref rom 7) #x10)
    (let ((condition (handler-case (progn (load-cartridge rom) nil)
                       (unsupported-mapper (condition) condition))))
      (check condition "unsupported mapper is reported")
      (check-equal (unsupported-mapper-number condition) #x10
                   "iNES decodes mapper byte 7 without shifting it twice"))))

(defun test-mapper2 ()
  (let* ((prg (make-array (* 3 #x4000)
                          :element-type '(unsigned-byte 8)
                          :initial-element 0))
         (cartridge nil)
         (bus nil))
    (loop for bank from 0 below 3
          do (loop for offset from 0 below #x4000
                   do (setf (aref prg (+ (* bank #x4000) offset))
                            (+ #x10 (* bank #x10)))))
    (setf cartridge (make-cartridge :prg-rom prg :mapper 2)
          bus (make-bus :cartridge cartridge))
    (check-equal (cartridge-read-prg cartridge #x8000) #x10
                 "UxROM starts with bank zero selected")
    (check-equal (cartridge-read-prg cartridge #xC000) #x30
                 "UxROM fixes the last PRG bank at $C000")
    (bus-write! bus #x8000 1)
    (check-equal (cartridge-read-prg cartridge #x8000) #x20
                 "UxROM switches the lower PRG bank")
    (check-equal (cartridge-read-prg cartridge #xC000) #x30
                 "UxROM bank switching preserves the fixed bank")
    (let ((rom (make-array (+ 16 (* 3 #x4000))
                           :element-type '(unsigned-byte 8)
                           :initial-element 0)))
      (setf (aref rom 0) #x4E
            (aref rom 1) #x45
            (aref rom 2) #x53
            (aref rom 3) #x1A
            (aref rom 4) 3
            (aref rom 5) 0
            (aref rom 6) #x20)
      (loop for bank from 0 below 3
            do (setf (aref rom (+ 16 (* bank #x4000)))
                     (+ #x40 bank)))
      (let ((loaded (load-cartridge rom)))
        (check-equal (cartridge-mapper loaded) 2
                     "iNES decodes the UxROM mapper number")
        (check-equal (cartridge-read-prg loaded #x8000) #x40
                     "loaded UxROM selects bank zero")
        (cartridge-write-prg! loaded #x8000 1)
        (check-equal (cartridge-read-prg loaded #x8000) #x41
                     "loaded UxROM switches banks")))))

(defun test-mapper3 ()
  (let* ((prg (make-array #x8000
                          :element-type '(unsigned-byte 8)
                          :initial-element 0))
         (chr (make-array (* 2 #x2000)
                          :element-type '(unsigned-byte 8)
                          :initial-element 0))
         (cartridge nil)
         (bus nil))
    (loop for bank from 0 below 2
          do (loop for offset from 0 below #x4000
                   do (setf (aref prg (+ (* bank #x4000) offset))
                            (+ #x10 (* bank #x10)))))
    (loop for bank from 0 below 2
          do (loop for offset from 0 below #x2000
                   do (setf (aref chr (+ (* bank #x2000) offset))
                            (+ #xA0 (* bank #x10)))))
    (setf cartridge (make-cartridge :prg-rom prg
                                    :chr-rom chr
                                    :mapper 3)
          bus (make-bus :cartridge cartridge))
    (check-equal (cartridge-mapper cartridge) 3
                 "direct construction accepts CNROM")
    (check-equal (cartridge-read-prg cartridge #x8000) #x10
                 "CNROM maps the first NROM PRG bank at $8000")
    (check-equal (cartridge-read-prg cartridge #xC000) #x20
                 "CNROM maps the second NROM PRG bank at $C000")
    (check-equal (cartridge-read-chr cartridge 0) #xA0
                 "CNROM starts with CHR bank zero")
    (check-equal (cartridge-read-chr cartridge #x1FFF) #xA0
                 "CNROM maps a complete 8 KiB CHR bank")
    (bus-write! bus #xC000 1)
    (check-equal (cartridge-read-chr cartridge 0) #xB0
                 "CNROM switches CHR banks on PRG writes")
    (check-equal (cartridge-read-chr cartridge #x1FFF) #xB0
                 "CNROM maps the selected CHR bank across $0000-$1FFF")
    (check-equal (cartridge-read-prg cartridge #x8000) #x10
                 "CNROM PRG remains fixed after CHR switching")
    (check-equal (cartridge-read-prg cartridge #xC000) #x20
                 "CNROM keeps the NROM upper PRG bank after writes")
    (check (signals-type-p 'invalid-rom
                           (lambda ()
                             (make-cartridge
                              :prg-rom (make-array #xC000
                                                   :element-type '(unsigned-byte 8))
                              :chr-rom chr
                              :mapper 3)))
           "CNROM rejects non-NROM PRG sizes")
    (check (signals-type-p 'invalid-rom
                           (lambda ()
                             (make-cartridge
                              :prg-rom (make-array #x4000
                                                   :element-type '(unsigned-byte 8))
                              :chr-rom (make-array #x3000
                                                   :element-type '(unsigned-byte 8))
                              :mapper 3)))
           "CNROM rejects non-8 KiB CHR banks"))
  (let ((rom (make-array (+ 16 #x4000 (* 2 #x2000))
                         :element-type '(unsigned-byte 8)
                         :initial-element 0)))
    (setf (aref rom 0) #x4E
          (aref rom 1) #x45
          (aref rom 2) #x53
          (aref rom 3) #x1A
          (aref rom 4) 1
          (aref rom 5) 2
          (aref rom 6) #x30
          (aref rom 7) 0
          (aref rom 16) #x3C)
    (loop for offset from 0 below #x2000
          do (setf (aref rom (+ 16 #x4000 offset)) #x31
                   (aref rom (+ 16 #x4000 #x2000 offset)) #x42))
    (let* ((loaded (load-cartridge rom))
           (bus (make-bus :cartridge loaded)))
      (check-equal (cartridge-mapper loaded) 3
                   "iNES 1.0 recognizes the CNROM mapper")
      (check-equal (cartridge-read-prg loaded #x8000) #x3C
                   "CNROM iNES PRG is mapped at $8000")
      (check-equal (cartridge-read-prg loaded #xC000) #x3C
                   "CNROM iNES 16 KiB PRG is mirrored at $C000")
      (check-equal (cartridge-read-chr loaded 0) #x31
                   "CNROM iNES starts with CHR bank zero")
      (check (not (cartridge-chr-writable-p loaded))
             "CNROM iNES CHR-ROM is read-only")
      (bus-write! bus #x8000 1)
      (check-equal (cartridge-read-chr loaded 0) #x42
                   "CNROM iNES switches CHR banks through the bus"))))

(defun test-mapper1 ()
  (let* ((prg (make-array (* 4 #x4000)
                          :element-type '(unsigned-byte 8)
                          :initial-element 0))
         (chr (make-array (* 8 #x1000)
                          :element-type '(unsigned-byte 8)
                          :initial-element 0))
         (cartridge nil)
         (bus nil))
    (loop for bank from 0 below 4
          do (loop for offset from 0 below #x4000
                   do (setf (aref prg (+ (* bank #x4000) offset))
                            (+ #x10 (* bank #x10)))))
    (loop for bank from 0 below 8
          do (loop for offset from 0 below #x1000
                   do (setf (aref chr (+ (* bank #x1000) offset))
                            (+ #xA0 bank))))
    (setf cartridge (make-cartridge :prg-rom prg :chr-rom chr :mapper 1)
          bus (make-bus :cartridge cartridge))
    (labels ((write-register (address value)
               (dotimes (bit 5)
                 (bus-write! bus address (ldb (byte 1 bit) value)))))
      (check-equal (cartridge-read-prg cartridge #x8000) #x10
                   "MMC1 starts with the first PRG bank")
      (check-equal (cartridge-read-prg cartridge #xC000) #x40
                   "MMC1 fixes the last PRG bank in mode 3")
      (write-register #x8000 #x00)
      (write-register #xE000 #x02)
      (check-equal (cartridge-read-prg cartridge #x8000) #x30
                   "MMC1 selects an even 32 KiB PRG bank")
      (check-equal (cartridge-read-prg cartridge #xC000) #x40
                   "MMC1 maps the upper half of the 32 KiB bank")
      (write-register #x8000 #x08)
      (write-register #xE000 #x01)
      (check-equal (cartridge-read-prg cartridge #x8000) #x10
                   "MMC1 mode 2 fixes the first PRG bank")
      (check-equal (cartridge-read-prg cartridge #xC000) #x20
                   "MMC1 mode 2 switches the upper PRG bank")
      (write-register #x8000 #x0C)
      (write-register #xE000 #x01)
      (check-equal (cartridge-read-prg cartridge #x8000) #x20
                   "MMC1 mode 3 switches the lower PRG bank")
      (check-equal (cartridge-read-prg cartridge #xC000) #x40
                   "MMC1 mode 3 keeps the last PRG bank fixed")
      (write-register #x8000 #x1C)
      (write-register #xA000 #x01)
      (write-register #xC000 #x02)
      (check-equal (cartridge-read-chr cartridge 0) #xA1
                   "MMC1 selects a 4 KiB CHR bank at $0000")
      (check-equal (cartridge-read-chr cartridge #x1000) #xA2
                   "MMC1 selects a 4 KiB CHR bank at $1000")
      (let ((ppu (make-ppu cartridge)))
        (ppu-write-vram! ppu #x2000 #x61)
        (check-equal (ppu-read-vram ppu #x2C00) #x61
                     "MMC1 lower single-screen mirroring aliases table 0")
        (write-register #x8000 #x1D)
        (ppu-write-vram! ppu #x2000 #x72)
          (check-equal (ppu-read-vram ppu #x2400) #x72
                       "MMC1 upper single-screen mirroring aliases table 1")))))


