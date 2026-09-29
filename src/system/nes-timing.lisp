(in-package #:cl-nes)

(defun %nes-clock-cpu-cycle! (nes bus cycle-hook pre-cycle-hook)
  (when pre-cycle-hook
    (funcall pre-cycle-hook))
  (%nes-tick! nes 1)
  (let ((cartridge (bus-cartridge bus)))
    (when (and cartridge (cartridge-cpu-clock-required-p cartridge))
      (cartridge-clock-cpu! cartridge 1)))
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
  (let ((bus (nes-bus nes)))
    (loop repeat dma-cycles
          do (%nes-poll-irq-before-clock! nes)
             (%nes-clock-cpu-cycle! nes bus cycle-hook nil)))
  dma-cycles)
