(in-package #:cl-nes)

(defun %nes-clock-cpu-cycle! (nes bus cycle-hook pre-cycle-hook
                                  &optional (ppu-ticks 3)
                                    (master-ticks 12)
                                    read-end-register)
  (when pre-cycle-hook
    (funcall pre-cycle-hook))
  (let* ((oam-read-end-p (eql read-end-register 4))
         (ppu-ticks-before-read
           (if (and oam-read-end-p (plusp ppu-ticks))
               (1- ppu-ticks)
               ppu-ticks)))
    (ppu-tick! (nes-ppu nes) ppu-ticks-before-read)
    (when read-end-register
      (incf (nes-master-clock nes) master-ticks))
    (let ((read-end-value
            (when read-end-register
              (ppu-read-register (nes-ppu nes) read-end-register t :end))))
      ;; OAMDATA samples the secondary OAM bus before dot 1 clears its latch.
      (when (and oam-read-end-p (plusp ppu-ticks))
        (ppu-tick! (nes-ppu nes) 1))
      (when *cpu-interrupt-vector-nmi-poll-hook*
        (%cpu-poll-interrupt-vector-nmi!))
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
             (disable-p
              (or (eq (apu-dmc-status-update-event dmc) :disabled)
                  (eq (apu-dmc-status-update-event dmc) :implicit-disabled)))
             (disable-stage (when disable-p (bus-dmc-dma-stage bus)))
             (trace-clock
               (when *dma-trace-hook*
                 (* 12 (incf *dma-trace-cycle-index*)))))
        (when trace-clock
          (%dma-trace-cycle! bus trace-clock :before-arbiter))
        (when disable-p
          (%dma-handle-dmc-disable!
           bus trace-clock disable-stage
           (eq (apu-dmc-status-update-event dmc) :implicit-disabled)))
        (%dma-arbitrate-cycle! bus)
        (when (and disable-p
                   (member disable-stage (list :active-halt :dummy)))
          (case disable-stage
            (:active-halt
             (when (eq (bus-dmc-dma-stage bus) :dummy)
               (setf (bus-dmc-dma-stage bus) :idle
                     (bus-dmc-dma-remaining bus) 0
                     (bus-dmc-dma-start-apu-phase bus) nil)
               (%dma-trace-event! bus :dmc-stop trace-clock
                                  :dmc-stop-reason :abort-cycle-consumed)))
            (:dummy
             (case (bus-dmc-dma-stage bus)
               (:get
                (setf (bus-dmc-dma-stage bus) :abort-get
                      (bus-dmc-dma-remaining bus) 1))
               (:alignment
                (setf (bus-dmc-dma-stage bus) :abort
                      (bus-dmc-dma-remaining bus) 1))))))
        (setf (apu-dmc-status-update-event dmc) nil)
        (when trace-clock
          (%dma-trace-cycle! bus trace-clock :after-arbiter)))
      (setf (bus-cpu-cycle-phase bus)
            (logxor (bus-cpu-cycle-phase bus) 1))
      ;; The next CPU-visible poll consumes this post-clock sample.
      (%nes-sample-irq-line! nes)
      (unless read-end-register
        (incf (nes-master-clock nes) master-ticks))
      (let ((cycle-hook-value (when cycle-hook (funcall cycle-hook))))
        (if read-end-register read-end-value cycle-hook-value)))))

(defun %nes-advance-master-ticks! (nes master-ticks)
  (let* ((phase (mod (- (nes-master-clock nes)
                        (nes-ppu-phase-offset nes))
                     4))
         (ppu-ticks (floor (+ phase master-ticks) 4)))
    (ppu-tick! (nes-ppu nes) ppu-ticks)
    (incf (nes-master-clock nes) master-ticks)
    ppu-ticks))

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
                            (quote (:active-halt :dummy :alignment :get
                                    :abort :abort-get))))
          do (%nes-clock-cpu-cycle! nes bus cycle-hook nil)
             (incf elapsed)
             (when (bus-dma-cycle-preempted-p bus)
               (incf remaining))
             (when (plusp remaining)
               (decf remaining)))
    elapsed))
