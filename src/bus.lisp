(in-package #:cl-nes)

(defun make-bus (&key cartridge ppu controller-1 controller-2 apu)
  (let* ((ppu (or ppu (make-ppu cartridge)))
         (controller-1 (or controller-1 (make-controller)))
         (controller-2 (or controller-2 (make-controller)))
         (apu (or apu (make-apu)))
         (bus nil))
    (ppu-load-cartridge! ppu cartridge)
    (setf bus (%make-bus cartridge ppu controller-1 controller-2 apu))
    ;; DMC reads use the same address decoder as the CPU, including PRG-ROM,
    ;; PRG-RAM and open-bus behavior.
    (apu-set-memory-reader!
     apu
     (lambda (address)
       ;; A DMC fetch is an internal device read.  It must use the CPU address
       ;; decoder, but it must not re-enter NES's per-CPU-access clock hook
       ;; while APU-TICK is already running.
       (with-bus-cpu-access-hook (bus nil)
         (bus-read bus address))))
    bus))

(defun %bus-read-device (bus address)
  (cond
    ((< address #x2000)
     (aref (bus-ram bus) (mod address #x800)))
    ((< address #x4000)
     (ppu-read-register (bus-ppu bus) (logand address 7) t))
    ((and (<= #x4000 address #x4015)
          (not (= address #x4014)))
     (apu-read-register (bus-apu bus) address))
    ((= address #x4016)
     (controller-read (bus-controller-1 bus)))
    ((= address #x4017)
     (controller-read (bus-controller-2 bus)))
    ((>= address #x4800)
     (cartridge-cpu-read (bus-cartridge bus) address))
    (t nil)))

(defun bus-read (bus address)
  (let ((value (%bus-read-device bus (logand address #xFFFF))))
    (setf value (logand (or value (bus-open-bus bus)) #xFF)
          (bus-open-bus bus) value)
    (let ((hook (bus-cpu-access-hook bus)))
      (when hook
        (funcall hook)))
    value))

(defun bus-write! (bus address value)
  (let ((address (logand address #xFFFF))
        (value (logand value #xFF)))
    (setf (bus-open-bus bus) value)
    (cond
      ((< address #x2000)
       (setf (aref (bus-ram bus) (mod address #x800)) value))
      ((< address #x4000)
       (ppu-write-register! (bus-ppu bus) (logand address 7) value))
      ((and (<= #x4000 address #x4013))
       (apu-write-register! (bus-apu bus) address value))
      ((= address #x4014)
       (%perform-oam-dma! bus value))
      ((= address #x4015)
       (apu-write-register! (bus-apu bus) address value))
      ((= address #x4016)
       (controller-write! (bus-controller-1 bus) value)
       (controller-write! (bus-controller-2 bus) value))
      ((= address #x4017)
       (apu-write-register! (bus-apu bus) address value))
      ((>= address #x5000)
       (cartridge-cpu-write! (bus-cartridge bus) address value))
      (t nil))
    (let ((hook (bus-cpu-access-hook bus)))
      (when hook
        (funcall hook)))
    value))
