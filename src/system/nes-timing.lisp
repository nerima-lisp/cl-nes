(in-package #:cl-nes)

(defun %nes-clock-cpu-cycle! (nes bus cycle-hook pre-cycle-hook &optional (ppu-ticks 3))
  (when pre-cycle-hook
    (funcall pre-cycle-hook))
  (progn
    (ppu-tick! (nes-ppu nes) ppu-ticks)
    (when *cpu-interrupt-vector-nmi-poll-hook*
      (%cpu-poll-interrupt-vector-nmi!)))
  (setf (apu-dmc-status-update-event (apu-dmc (nes-apu nes))) nil)
  (apu-tick! (nes-apu nes) 1)
  (when *dma-trace-hook*
    (%dma-trace-event! bus :apu-tick
                       (* 12 (1+ *dma-trace-cycle-index*))
                       :apu-tick-index (1+ *dma-trace-cycle-index*)))
  (let ((cartridge (bus-cartridge bus)))
    (when (and cartridge (cartridge-cpu-clock-required-p cartridge))
      (cartridge-clock-cpu! cartridge 1)))
  (let* ((dmc (apu-dmc (nes-apu nes)))
         (disable-p (eq (apu-dmc-status-update-event dmc) :disabled))
         (disable-stage (when disable-p (bus-dmc-dma-stage bus)))
         (trace-clock
           (when *dma-trace-hook*
             (* 12 (incf *dma-trace-cycle-index*)))))
    (when trace-clock
      (%dma-trace-cycle! bus trace-clock :before-arbiter))
    (when disable-p
      (%dma-handle-dmc-disable! bus trace-clock disable-stage))
    (%dma-arbitrate-cycle! bus)
    (when (and disable-p
               (eq disable-stage :active-halt)
               (eq (bus-dmc-dma-stage bus) :dummy))
      (setf (bus-dmc-dma-stage bus) :abort
            (bus-dmc-dma-remaining bus) 1))
    (setf (apu-dmc-status-update-event dmc) nil)
    (when trace-clock
      (%dma-trace-cycle! bus trace-clock :after-arbiter)))
  (setf (bus-cpu-cycle-phase bus)
        (logxor (bus-cpu-cycle-phase bus) 1))
  ;; The next CPU-visible poll consumes this post-clock sample.
  (%nes-sample-irq-line! nes)
  (incf (nes-master-clock nes) 12)
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
                    (member (bus-dmc-dma-stage bus)
                            '(:active-halt :dummy :alignment :get :abort)))
          do (%nes-clock-cpu-cycle! nes bus cycle-hook nil)
             (incf elapsed)
             (when (bus-dma-cycle-preempted-p bus)
               (incf remaining))
             (when (plusp remaining)
               (decf remaining)))
    elapsed))
