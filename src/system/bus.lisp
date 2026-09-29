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
       ;; The current APU interface services the byte synchronously; charge
       ;; the corresponding DMC halt so the next NES step consumes it.  A
       ;; halt attempted during a read costs four clocks; a write attempt is
       ;; delayed until the next get/put phase and is three or four clocks.
       (let* ((write-p (eq (bus-last-cpu-access-kind bus) :write))
              (stall (if (and write-p (oddp (bus-cpu-cycle-phase bus)))
                         3
                         4)))
         (incf (bus-dma-stall-cycles bus) stall)
         ;; 2A03 repeats the CPU read during halt/dummy cycles.  These reads
         ;; are deliberately hook-free, but retain register side effects.
         (loop repeat (1- stall)
               do
           (%bus-read-device bus (bus-last-cpu-access-address bus))))
       (with-bus-cpu-access-hook (bus nil)
         (%bus-read-device bus address))))
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
    ((bus-cartridge bus)
     (cartridge-cpu-read (bus-cartridge bus) address))
    (t nil)))

(defun bus-read (bus address)
  (let ((address (logand address #xFFFF)))
    (setf (bus-last-cpu-access-kind bus) :read
          (bus-last-cpu-access-address bus) address)
    (let ((value (%bus-read-device bus address)))
      (setf value (logand (or value (bus-open-bus bus)) #xFF)
            (bus-open-bus bus) value)
      (%bus-cpu-access! bus)
      value)))

(defun %perform-oam-dma! (bus page)
  (let ((base (ash (logand page #xFF) 8)))
    ;; The transfer is a device operation. Its 256 source reads must not be
    ;; counted as 256 additional CPU bus cycles by the instruction hook.
    (with-bus-cpu-access-hook (bus nil)
      (loop for offset below 256 do
        (ppu-write-register! (bus-ppu bus) 4
                              (bus-read bus (+ base offset)))))
    ;; DMA occupies 513 or 514 CPU cycles depending on the phase of the CPU
    ;; cycle on which $4014 was written.  The transfer itself is already
    ;; complete; NES consumes this stall after the instruction returns.
    (setf (bus-dma-stall-cycles bus)
          (+ (bus-dma-stall-cycles bus)
             513
             (bus-cpu-cycle-phase bus)))))

(defun bus-take-dma-stall-cycles! (bus)
  (prog1 (bus-dma-stall-cycles bus)
    (setf (bus-dma-stall-cycles bus) 0)))

(defun bus-write! (bus address value)
  (let ((address (logand address #xFFFF))
        (value (logand value #xFF)))
    (setf (bus-last-cpu-access-kind bus) :write
          (bus-last-cpu-access-address bus) address)
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
      ((bus-cartridge bus)
       (cartridge-cpu-write!
        (bus-cartridge bus) address value
        (when (bus-cpu-access-active-p bus)
          (+ (cpu-cycles (nes-cpu (bus-cpu-access-nes bus)))
             (bus-cpu-access-count bus)))))
      (t nil))
    (%bus-cpu-access! bus)
    value))

(defun %bus-cpu-access! (bus)
  (if (bus-cpu-access-active-p bus)
      (progn
        (incf (bus-cpu-access-count bus))
        (%nes-clock-cpu-cycle! (bus-cpu-access-nes bus)
                               bus
                               (bus-cpu-access-cycle-hook bus)
                               (bus-cpu-access-pre-cycle-hook bus)))
      (let ((hook (bus-cpu-access-hook bus)))
        (when hook
          (funcall hook)))))
