(in-package #:cl-nes)

(defun %nes-reset-cpu-and-clock! (nes)
  ;; The CPU reset sequence consumes seven clocks before fetching the reset
  ;; vector.  The APU's power/reset phase must include those clocks; the
  ;; existing PPU reset contract starts its visible dot at zero.
  (cpu-reset! (nes-cpu nes) (nes-bus nes))
  (apu-tick! (nes-apu nes) 7)
  nes)

(defun make-nes (&key cartridge ppu controller-1 controller-2 apu)
  (when cartridge
    (cartridge-reset! cartridge))
  (let* ((ppu (or ppu (make-ppu cartridge)))
         (bus (make-bus :cartridge cartridge
                        :ppu ppu
                        :controller-1 controller-1
                        :controller-2 controller-2
                        :apu apu))
         (cpu (make-cpu)))
    (let ((nes (%make-nes cpu bus ppu (bus-apu bus))))
      (when cartridge
        (%nes-reset-cpu-and-clock! nes))
      nes)))

(defun nes-load-cartridge! (nes cartridge)
  (setf (bus-cartridge (nes-bus nes)) cartridge)
  (setf (bus-dma-stall-cycles (nes-bus nes)) 0)
  (when cartridge
    (cartridge-reset! cartridge))
  (ppu-load-cartridge! (nes-ppu nes) cartridge)
  (apu-reset! (nes-apu nes))
  (%nes-reset-cpu-and-clock! nes)
  nes)

(defun nes-reset! (nes)
  (setf (bus-dma-stall-cycles (nes-bus nes)) 0)
  (when (bus-cartridge (nes-bus nes))
    (cartridge-reset! (bus-cartridge (nes-bus nes))))
  (ppu-reset! (nes-ppu nes))
  (apu-console-reset! (nes-apu nes))
  (%nes-reset-cpu-and-clock! nes)
  nes)

(defun %nes-tick! (nes cycles)
  (ppu-tick! (nes-ppu nes) (* 3 cycles))
  (apu-tick! (nes-apu nes) cycles))
