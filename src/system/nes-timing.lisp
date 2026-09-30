(in-package #:cl-nes)

(defun %nes-clock-cpu-cycle! (nes bus cycle-hook pre-cycle-hook
                              &optional (ppu-ticks 3))
  (when pre-cycle-hook
    (funcall pre-cycle-hook))
  (ppu-tick! (nes-ppu nes) ppu-ticks)
  (apu-tick! (nes-apu nes) 1)
  (let ((cartridge (bus-cartridge bus)))
    (when (and cartridge (cartridge-cpu-clock-required-p cartridge))
      (cartridge-clock-cpu! cartridge 1)))
  (%bus-advance-dma-cycle! bus)
  (setf (bus-cpu-cycle-phase bus)
        (logxor (bus-cpu-cycle-phase bus) 1))
  (when cycle-hook
    (funcall cycle-hook)))

(defun %nes-complete-cpu-operation!
    (nes bus cycles accesses cycle-hook pre-cycle-hook)
  (when cycles
    (loop repeat (max 0 (- cycles accesses))
          do (%nes-clock-cpu-cycle! nes bus cycle-hook pre-cycle-hook)))
  cycles)

(defun %nes-run-dma-stalls! (nes dma-cycles &optional cycle-hook)
  (let ((bus (nes-bus nes))
        (remaining dma-cycles)
        (elapsed 0))
    (loop while (or (plusp remaining)
                    (bus-oam-dma-active-p bus)
                    (plusp (bus-dmc-dma-remaining bus)))
          do (%nes-poll-irq-before-clock! nes)
             (%nes-clock-cpu-cycle! nes bus cycle-hook nil)
             (incf elapsed)
             (when (bus-dma-cycle-preempted-p bus)
               (incf remaining))
             (when (plusp remaining)
               (decf remaining)))
    elapsed))
