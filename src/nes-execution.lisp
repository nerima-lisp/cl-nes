(in-package #:cl-nes)

(defun %nes-run-instruction! (nes &optional nmi-poll cycle-hook pre-cycle-hook)
  (with-nes-cpu-operation (nes cycle-hook pre-cycle-hook)
    (cpu-step! (nes-cpu nes) (nes-bus nes) nmi-poll)))

(defun %nes-run-interrupt! (nes type &optional brk-p nmi-poll cycle-hook
                                          pre-cycle-hook)
  (with-nes-cpu-operation (nes cycle-hook pre-cycle-hook)
    (cpu-interrupt! (nes-cpu nes) (nes-bus nes) type brk-p nmi-poll)))

(defun %nes-irq-eligible-p (cpu irq-disabled-at-start)
  (if (plusp (cpu-irq-delay cpu))
      (not irq-disabled-at-start)
      (not (%flag-set-p cpu +flag-interrupt-disable+))))

(defun %nes-cartridge-irq-pending-p (nes)
  (let ((cartridge (bus-cartridge (nes-bus nes))))
    (and cartridge
         (cartridge-irq-pending-p cartridge))))

(defun %nes-irq-pending-p (nes)
  (or (apu-irq-pending-p (nes-apu nes))
      (%nes-cartridge-irq-pending-p nes)))

(defun %nes-take-nmi! (nes)
  "Consume an NMI edge which is already visible to the CPU."
  (let ((ppu (nes-ppu nes)))
    (and (ppu-nmi-pending-p ppu)
         (not (ppu-nmi-delay-p ppu))
         (ppu-take-nmi! ppu))))

(defun %nes-poll-nmi-during-operation! (nes)
  "Consume an NMI at an interrupt-response vector polling point.

The PPU models the short propagation delay separately from the pending edge.
At the CPU's vector polling point both states are observable: the first read
advances a delayed edge to the CPU, and the following poll consumes it."
  (let ((ppu (nes-ppu nes)))
    (when (and (ppu-nmi-pending-p ppu)
               (ppu-nmi-delay-p ppu))
      (ppu-take-nmi! ppu))
    (%nes-take-nmi! nes)))

(defun nes-step/k (nes continuation &key cycle-hook)
  "Run one NES step and pass its CPU-cycle count to CONTINUATION.

The continuation is called after instruction, DMA, and interrupt clocks have
been applied.  CYCLE-HOOK, when supplied, is called after every elapsed CPU
cycle, including DMA and interrupt clocks.  The function returns the
continuation's result."
  (let* ((cpu (nes-cpu nes))
         (irq-disabled-at-start
           (%flag-set-p cpu +flag-interrupt-disable+))
         ;; An IRQ asserted by the clocks of this instruction is normally
         ;; sampled at this boundary.  A taken, non-page-crossing branch marks
         ;; its final clock as the one 6502 exception.  Keep the observation
         ;; history at the clock boundary rather than only looking at the
         ;; line after the whole instruction: a read of $4015 can clear the
         ;; APU source before the CPU reaches its interrupt poll.
         (irq-seen-p (%nes-irq-pending-p nes))
         (irq-seen-before-last-p irq-seen-p)
         (nmi-hijacked-p nil))
    (labels ((poll-irq-before-clock ()
               (setf irq-seen-before-last-p irq-seen-p)
               (when (%nes-irq-pending-p nes)
                 (setf irq-seen-p t)))
             (poll-nmi-event ()
               (when (%nes-poll-nmi-during-operation! nes)
                 (setf nmi-hijacked-p t)
                 t)))
      (let ((cycles
              (%nes-run-instruction!
               nes #'poll-nmi-event cycle-hook #'poll-irq-before-clock)))
        (let ((dma-cycles (bus-take-dma-stall-cycles! (nes-bus nes))))
          (when (plusp dma-cycles)
            (incf cycles
                  (%nes-run-dma-stalls! nes dma-cycles
                                         #'poll-irq-before-clock
                                         cycle-hook)))
          ;; NMI is sampled before maskable IRQ, matching the 6502 priority.
          (let ((nmi-taken-p
                  (or nmi-hijacked-p
                      (ppu-take-nmi! (nes-ppu nes)))))
            (when (and nmi-taken-p (not nmi-hijacked-p))
              (incf cycles (%nes-run-interrupt!
                            nes :nmi nil nil cycle-hook nil)))
            (when (and (not nmi-taken-p)
                       (zerop dma-cycles)
                       (or (not (cpu-irq-poll-delay cpu))
                           irq-seen-before-last-p)
                       (%nes-irq-eligible-p cpu irq-disabled-at-start)
                       irq-seen-p)
              (let ((interrupt-cycles
                      (%nes-run-interrupt!
                       nes :irq t #'poll-nmi-event
                       cycle-hook #'poll-irq-before-clock)))
                (when interrupt-cycles
                  (incf cycles interrupt-cycles)))))
          ;; CLI/SEI/PLP delay IRQ recognition for the following instruction.
          (when (plusp (cpu-irq-delay cpu))
            (decf (cpu-irq-delay cpu)))
          (funcall continuation cycles))))))

(defun nes-run-frame/k (nes continuation &key cycle-hook)
  "Run until a frame is ready and pass its framebuffer to CONTINUATION."
  (setf (ppu-frame-ready-p (nes-ppu nes)) nil)
  (loop until (ppu-frame-ready-p (nes-ppu nes))
        do (nes-step/k nes #'identity :cycle-hook cycle-hook))
  (funcall continuation (ppu-framebuffer (nes-ppu nes))))
