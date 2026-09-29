(in-package #:cl-nes)

(defun %nes-reset-cpu-and-clock! (nes)
  ;; The CPU reset sequence consumes seven clocks before fetching the reset
  ;; vector.  The APU's power/reset phase must include those clocks, and the
  ;; PPU must advance three dots for each of them.  Direct PPU reset still
  ;; starts at dot zero; this phase belongs to the complete NES reset.
  (cpu-reset! (nes-cpu nes) (nes-bus nes))
  (setf (bus-cpu-cycle-phase (nes-bus nes))
        (mod (cpu-cycles (nes-cpu nes)) 2))
  (ppu-tick! (nes-ppu nes) 21)
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
    (let ((nes (%make-nes :cpu cpu :bus bus :ppu ppu :apu (bus-apu bus))))
      (when cartridge
        (%nes-reset-cpu-and-clock! nes))
      nes)))

(defun nes-load-cartridge! (nes cartridge)
  (setf (bus-cartridge (nes-bus nes)) cartridge)
  (let ((bus (nes-bus nes)))
    (setf (bus-dma-stall-cycles bus) 0
          (bus-oam-dma-active-p bus) nil
          (bus-oam-dma-index bus) 0
          (bus-oam-dma-stage bus) :halt
          (bus-oam-dma-alignment-p bus) nil
          (bus-dmc-dma-remaining bus) 0
          (bus-dmc-read-replay-p bus) nil
          (bus-dma-cycle-preempted-p bus) nil))
  (when cartridge
    (cartridge-reset! cartridge))
  (ppu-load-cartridge! (nes-ppu nes) cartridge)
  (apu-reset! (nes-apu nes))
  (%nes-reset-cpu-and-clock! nes)
  nes)

(defun nes-initialize! (nes &key pc)
  "Reset NES and optionally select the CPU entry point for a ROM harness."
  (nes-reset! nes)
  (when pc
    (setf (cpu-pc (nes-cpu nes)) pc))
  nes)

(defun nes-reset! (nes)
  (let ((bus (nes-bus nes)))
    (setf (bus-dma-stall-cycles bus) 0
          (bus-oam-dma-active-p bus) nil
          (bus-oam-dma-index bus) 0
          (bus-oam-dma-stage bus) :halt
          (bus-oam-dma-alignment-p bus) nil
          (bus-dmc-dma-remaining bus) 0
          (bus-dmc-read-replay-p bus) nil
          (bus-dma-cycle-preempted-p bus) nil))
  (when (bus-cartridge (nes-bus nes))
    (cartridge-reset! (bus-cartridge (nes-bus nes))))
  (ppu-reset! (nes-ppu nes))
  (apu-console-reset! (nes-apu nes))
  (%nes-reset-cpu-and-clock! nes)
  nes)

(defun %nes-tick! (nes cycles)
  (ppu-tick! (nes-ppu nes) (* 3 cycles))
  (apu-tick! (nes-apu nes) cycles))
