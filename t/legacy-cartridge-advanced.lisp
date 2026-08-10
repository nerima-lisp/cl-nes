(in-package #:cl-nes/test-runner)

(defun test-mapper5 ()
  (let* ((prg (make-banked-rom 2 #x2000))
         (cartridge (make-cartridge :prg-rom prg :mapper 5))
         (bus (make-bus :cartridge cartridge)))
    ;; $5117 is ROM-only even when software writes a value with bit 7 clear.
    (setf (aref (cartridge-prg-rom cartridge) #x3FF7) #x4C
          (aref (cartridge-prg-rom cartridge) #x3FF8) #x00
          (aref (cartridge-prg-rom cartridge) #x3FF9) #x80)
    (bus-write! bus #x5100 0)
    (bus-write! bus #x5117 #x10)
    (check-equal (cartridge-read-prg cartridge #xFFF7) #x4C
                 "MMC5 $5117 remains mapped to PRG-ROM in 32 KiB mode")
    (check-equal (cartridge-read-prg cartridge #xFFF8) #x00
                 "MMC5 maps the complete fixed 32 KiB window")
    (check-equal (cartridge-read-prg cartridge #xFFF9) #x80
                 "MMC5 preserves the reset jump target")))

(defun test-discrete-mappers ()
  (let* ((cartridge (make-cartridge
                     :prg-rom (make-banked-rom 2 #x8000 #x10)
                     :mapper 7))
         (bus (make-bus :cartridge cartridge)))
    (check-equal (cartridge-read-prg cartridge #x8000) #x10
                 "AxROM starts with PRG bank zero")
    (bus-write! bus #x8000 #x11)
    (check-equal (cartridge-read-prg cartridge #x8000) #x11
                 "AxROM selects a 32 KiB PRG bank")
    (check-equal (cartridge-mirroring cartridge) :single-screen-upper
                 "AxROM bit 4 selects upper single-screen mirroring"))
  (let* ((cartridge (make-cartridge
                     :prg-rom (make-banked-rom 2 #x8000 #x20)
                     :chr-rom (make-banked-rom 2 #x2000 #x40)
                     :mapper 11))
         (bus (make-bus :cartridge cartridge)))
    (bus-write! bus #x8000 #x11)
    (check-equal (cartridge-read-prg cartridge #x8000) #x21
                 "Color Dreams selects a 32 KiB PRG bank")
    (check-equal (cartridge-read-chr cartridge 0) #x41
                 "Color Dreams selects an 8 KiB CHR bank"))
  (let* ((cartridge (make-cartridge
                     :prg-rom (make-banked-rom 4 #x2000 #x50)
                     :chr-rom (make-banked-rom 32 #x0400 #x60)
                     :mapper 22))
         (bus (make-bus :cartridge cartridge)))
    (check-equal (cartridge-read-prg cartridge #xC000) #x52
                 "VRC2a fixes the penultimate PRG bank at $C000")
    (check-equal (cartridge-read-prg cartridge #xE000) #x53
                 "VRC2a fixes the last PRG bank at $E000")
    (bus-write! bus #x8000 1)
    (bus-write! bus #xA000 0)
    (check-equal (cartridge-read-prg cartridge #x8000) #x51
                 "VRC2a switches the first 8 KiB PRG window")
    (check-equal (cartridge-read-prg cartridge #xA000) #x50
                 "VRC2a switches the second 8 KiB PRG window")
    (bus-write! bus #xB000 #x04)
    (bus-write! bus #xB002 #x01)
    (check-equal (cartridge-read-chr cartridge 0) #x6A
                 "VRC2a swaps A0/A1 and shifts the CHR bank value")
    (bus-write! bus #x9000 1)
    (check-equal (cartridge-mirroring cartridge) :horizontal
                 "VRC2a changes nametable mirroring"))
  (let* ((cartridge (make-cartridge
                     :prg-rom (make-banked-rom 32 #x4000)
                     :mapper 28))
         (bus (make-bus :cartridge cartridge)))
    (check-equal (cartridge-read-prg cartridge #x8000) 30
                 "Action53 reset mapping exposes the penultimate PRG bank")
    (check-equal (cartridge-read-prg cartridge #xC000) 31
                 "Action53 reset mapping exposes the last PRG bank")
    (bus-write! bus #x5000 #x80)
    (bus-write! bus #x8000 #x0C)
    (bus-write! bus #x5000 #x00)
    (bus-write! bus #x8000 #x11)
    (check-equal (cartridge-mirroring cartridge) :single-screen-upper
                 "Action53 user-register writes update the mirroring bit from D4")
    (cartridge-write-chr! cartridge 0 #xA5)
    (bus-write! bus #x5000 #x01)
    (bus-write! bus #x8000 #x00)
    (check-equal (cartridge-mirroring cartridge) :single-screen-lower
                 "Action53 register 1 also updates the shared mirroring bit")
    (bus-write! bus #x5000 #x00)
    (bus-write! bus #x8000 #x00)
    (check-equal (cartridge-read-chr cartridge 0) 0
                 "Action53 switches 8 KiB CHR-RAM banks")
    (bus-write! bus #x8000 #x01)
    (check-equal (cartridge-read-chr cartridge 0) #xA5
                 "Action53 restores data from the selected CHR-RAM bank"))
  (let* ((cartridge (make-cartridge
                     :prg-rom (make-banked-rom 2 #x8000 #x70)
                     :mapper 34))
         (bus (make-bus :cartridge cartridge)))
    (bus-write! bus #x8000 1)
    (check-equal (cartridge-read-prg cartridge #x8000) #x71
                 "BNROM selects a 32 KiB PRG bank"))
  (let* ((cartridge (make-cartridge
                     :prg-rom (make-banked-rom 4 #x2000)
                     :chr-rom (make-banked-rom 8 #x0400)
                     :mapper 4))
         (bus (make-bus :cartridge cartridge)))
    (bus-write! bus #xC000 1)
    (bus-write! bus #xC001 0)
    (bus-write! bus #xE001 0)
    (cl-nes::cartridge-clock-ppu-a12! cartridge nil 24)
    (cl-nes::cartridge-clock-ppu-a12! cartridge t)
    (check-equal (cl-nes::cartridge-mapper4-irq-counter cartridge) 1
                 "MMC3 clocks IRQ on a sufficiently long A12 low phase")
    (cl-nes::cartridge-clock-ppu-a12! cartridge nil 1)
    (cl-nes::cartridge-clock-ppu-a12! cartridge t)
    (check-equal (cl-nes::cartridge-mapper4-irq-counter cartridge) 1
                 "MMC3 ignores a short A12 low phase")
    (cl-nes::cartridge-clock-ppu-a12! cartridge nil 24)
    (cl-nes::cartridge-clock-ppu-a12! cartridge t)
    (check (cl-nes::cartridge-irq-pending-p cartridge)
           "MMC3 raises IRQ after the filtered A12 clock"))
  (let* ((cartridge (make-cartridge
                     :prg-rom (make-banked-rom 4 #x2000)
                     :chr-rom (make-banked-rom 8 #x0400)
                     :mapper 4
                     :mapper4-variant :mmc6))
         (bus (make-bus :cartridge cartridge)))
    (flet ((clock-a12 ()
             (cl-nes::cartridge-clock-ppu-a12! cartridge nil 24)
             (cl-nes::cartridge-clock-ppu-a12! cartridge t)))
      (bus-write! bus #xC000 0)
      (bus-write! bus #xC001 0)
      (bus-write! bus #xE001 0)
      (clock-a12)
      (check (cl-nes::cartridge-irq-pending-p cartridge)
             "MMC6 raises IRQ when reloading zero after a clear")
      (bus-write! bus #xE000 0)
      (bus-write! bus #xC000 1)
      (bus-write! bus #xC001 0)
      (bus-write! bus #xE001 0)
      (clock-a12)
      (bus-write! bus #xC000 0)
      (clock-a12)
      (check (cl-nes::cartridge-irq-pending-p cartridge)
             "MMC6 raises IRQ when the counter normally reaches zero")
      (bus-write! bus #xE000 0)
      (clock-a12)
      (check (not (cl-nes::cartridge-irq-pending-p cartridge))
             "MMC6 suppresses IRQ when reloading after normal zero"))))

(defun test-nes2-header ()
  (let ((rom (make-array (+ 16 #x4000)
                         :element-type '(unsigned-byte 8)
                         :initial-element 0)))
    (setf (aref rom 0) #x4E
          (aref rom 1) #x45
          (aref rom 2) #x53
          (aref rom 3) #x1A
          (aref rom 4) 1
          (aref rom 5) 0
          (aref rom 6) #x70
          (aref rom 7) #x08
          (aref rom 10) #x07
          (aref rom 16) #xA7)
    (let ((cartridge (load-cartridge rom)))
      (check-equal (cartridge-mapper cartridge) 7
                   "NES 2.0 header preserves the mapper number")
      (check-equal (cartridge-read-prg cartridge #x8000) #xA7
                   "NES 2.0 linear PRG size is accepted")
      (check (cartridge-chr-writable-p cartridge)
             "NES 2.0 CHR size zero creates CHR-RAM")
      (check-equal (length (cartridge-chr-rom cartridge)) #x2000
                   "NES 2.0 creates the mapper CHR-RAM window")
      (check-equal (length (cartridge-prg-ram cartridge)) #x2000
                   "NES 2.0 decodes PRG-RAM shift sizes"))))


