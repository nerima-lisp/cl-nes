(in-package #:cl-nes)

(defun make-bus (&key cartridge ppu controller-1 controller-2 apu)
  (let* ((ppu (or ppu (make-ppu cartridge)))
         (controller-1 (or controller-1 (make-controller)))
         (controller-2 (or controller-2 (make-controller)))
         (apu (or apu (make-apu)))
         (bus nil))
    (ppu-load-cartridge! ppu cartridge)
    (setf bus (%make-bus :cartridge cartridge :ppu ppu
                          :controller-1 controller-1 :controller-2 controller-2
                          :apu apu))
    ;; DMC reads use the same address decoder as the CPU, including PRG-ROM,
    ;; PRG-RAM and open-bus behavior.
    (apu-set-memory-reader!
     apu
     (lambda (address)
       ;; A DMC fetch is an internal device read.  It must use the CPU address
       ;; decoder, but it must not re-enter NES's per-CPU-access clock hook
       ;; while APU-TICK is already running.
       ;; The APU requests the byte synchronously, while the bus retains the
       ;; DMA's dummy/alignment cycles for the clocked DMA state machine.
       (with-bus-cpu-access-hook (bus nil)
         (let* ((write-p (eq (bus-last-cpu-access-kind bus) :write))
                (stall (if (and write-p (oddp (bus-cpu-cycle-phase bus)))
                           3
                           4)))
           (if (bus-oam-dma-active-p bus)
               (progn
                 (setf (bus-dmc-dma-remaining bus) (1- stall))
                 ;; The sample get is performed by the DMA request.  It must
                 ;; not enter BUS-READ while OAM arbitration is active.
                 (logand (or (%bus-read-device bus address)
                             (bus-open-bus bus))
                         #xFF))
               (progn
                 (incf (bus-dma-stall-cycles bus) stall)
                 ;; Preserve the established standalone DMC timing path.
                 (loop repeat (1- stall)
                       do (%bus-read-device
                           bus (bus-last-cpu-access-address bus)))
                 (bus-read bus address)))))))
    bus))

(defun %bus-read-device (bus address)
  (cond
    ((< address #x2000)
     (aref (bus-ram bus) (mod address #x800)))
    ((< address #x4000)
     (ppu-read-register (bus-ppu bus) (logand address 7) t))
    ((and (<= #x4000 address #x4015)
          (not (= address #x4014)))
     (apu-read-register (bus-apu bus) address (bus-cpu-cycle-phase bus)))
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
    ;; A CPU read observes PPU status late in its cycle.  Advance the PPU to
    ;; the final two dots before the device read, then charge the last dot in
    ;; the normal CPU-cycle clock below.
    (let ((ppu-ticks 3))
      (when (and (bus-cpu-access-active-p bus)
                 (< address #x4000)
                 (= (logand address 7) 2))
        (ppu-tick! (bus-ppu bus) 2)
        (setf ppu-ticks 1))
      (let ((value (%bus-read-device bus address)))
        (setf value (logand (or value (bus-open-bus bus)) #xFF)
              (bus-open-bus bus) value)
        (%bus-cpu-access! bus ppu-ticks)
        value))))

(defun %perform-oam-dma! (bus page)
  (if (bus-cpu-access-active-p bus)
      (setf (bus-oam-dma-active-p bus) t
            (bus-oam-dma-page bus) (logand page #xFF)
            (bus-oam-dma-index bus) 0
            (bus-oam-dma-stage bus) :halt
            (bus-oam-dma-alignment-p bus)
            (= (bus-cpu-cycle-phase bus) 1)
            (bus-dma-stall-cycles bus)
            (+ (bus-dma-stall-cycles bus)
               513
               (bus-cpu-cycle-phase bus)))
      (let ((base (ash (logand page #xFF) 8)))
        ;; Direct bus fixtures have no NES clock owner.  Preserve their
        ;; synchronous transfer semantics; CPU execution uses the state path.
        (with-bus-cpu-access-hook (bus nil)
          (loop for offset below 256 do
            (ppu-write-register! (bus-ppu bus) 4
                                 (bus-read bus (+ base offset)))))
        (setf (bus-dma-stall-cycles bus)
              (+ (bus-dma-stall-cycles bus)
                 513
                 (bus-cpu-cycle-phase bus))))))

(defun %bus-dma-dummy-read! (bus)
  (%bus-read-device bus (bus-last-cpu-access-address bus)))

(defun %bus-advance-dma-cycle! (bus)
  (setf (bus-dma-cycle-preempted-p bus) nil)
  (let ((dmc-active-p (plusp (bus-dmc-dma-remaining bus))))
    (when (plusp (bus-dmc-dma-remaining bus))
      (when (> (bus-dmc-dma-remaining bus) 1)
        (%bus-dma-dummy-read! bus))
      (decf (bus-dmc-dma-remaining bus)))
    (when (bus-oam-dma-active-p bus)
      (case (bus-oam-dma-stage bus)
        (:halt
         (setf (bus-oam-dma-stage bus)
               (if (bus-oam-dma-alignment-p bus) :alignment :get)))
        (:alignment
         (%bus-dma-dummy-read! bus)
         (setf (bus-oam-dma-stage bus) :get))
        (:get
         (if dmc-active-p
             (setf (bus-dma-cycle-preempted-p bus) t)
             (progn
               (let ((address (+ (ash (bus-oam-dma-page bus) 8)
                                 (bus-oam-dma-index bus))))
                 (setf (bus-open-bus bus)
                       (logand (or (%bus-read-device bus address)
                                   (bus-open-bus bus))
                               #xFF)))
               (setf (bus-oam-dma-stage bus) :put))))
        (:put
         (ppu-write-register! (bus-ppu bus) 4 (bus-open-bus bus))
         (incf (bus-oam-dma-index bus))
         (if (= (bus-oam-dma-index bus) 256)
             (setf (bus-oam-dma-active-p bus) nil)
             (setf (bus-oam-dma-stage bus) :get)))))))

(defun bus-take-dma-stall-cycles! (bus)
  (prog1 (bus-dma-stall-cycles bus)
    (setf (bus-dma-stall-cycles bus) 0)))

(defun bus-write! (bus address value)
  (let ((address (logand address #xFFFF))
        (value (logand value #xFF))
        (ppu-ticks 3)
        (previous-address (bus-last-cpu-access-address bus)))
    (setf (bus-last-cpu-access-kind bus) :write
          (bus-last-cpu-access-address bus) address)
    (setf (bus-open-bus bus) value)
    (when (and (bus-cpu-access-active-p bus)
               (< address #x4000)
               (= (logand address 7) 0)
               (not (logbitp 7 value)))
      (ppu-tick! (bus-ppu bus) 3)
      (setf ppu-ticks 0))
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
       (let ((strobe-p (or (not (logbitp 0 value))
                           (not (= previous-address #x4016))
                           (= (bus-cpu-cycle-phase bus) 0))))
         (controller-write! (bus-controller-1 bus) value :strobe-p strobe-p)
         (controller-write! (bus-controller-2 bus) value :strobe-p strobe-p)))
      ((= address #x4017)
       (apu-write-register! (bus-apu bus) address value))
      ((bus-cartridge bus)
       (cartridge-cpu-write!
        (bus-cartridge bus) address value
        (when (bus-cpu-access-active-p bus)
          (+ (cpu-cycles (nes-cpu (bus-cpu-access-nes bus)))
             (bus-cpu-access-count bus)))))
      (t nil))
    (%bus-cpu-access! bus ppu-ticks)
    value))

(defun %bus-cpu-access! (bus &optional (ppu-ticks 3))
  (if (bus-cpu-access-active-p bus)
      (progn
        (incf (bus-cpu-access-count bus))
        (%nes-clock-cpu-cycle! (bus-cpu-access-nes bus)
                               bus
                               (bus-cpu-access-cycle-hook bus)
                               (bus-cpu-access-pre-cycle-hook bus)
                               ppu-ticks))
      (let ((hook (bus-cpu-access-hook bus)))
        (when hook
          (funcall hook)))))
