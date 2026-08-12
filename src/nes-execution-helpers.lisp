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

(defun %nes-boundary-nmi-taken-p (nes nmi-hijacked-p)
  (or nmi-hijacked-p
      (ppu-take-nmi! (nes-ppu nes))))

(defun %nes-irq-deliverable-p (cpu irq-disabled-at-start dma-cycles
                               irq-seen-p irq-seen-before-last-p)
  (and (zerop dma-cycles)
       (or (not (cpu-irq-poll-delay cpu))
           irq-seen-before-last-p)
       (%nes-irq-eligible-p cpu irq-disabled-at-start)
       irq-seen-p))

(defun %nes-run-post-instruction-interrupts!
    (nes cpu irq-disabled-at-start dma-cycles
     irq-seen-p irq-seen-before-last-p nmi-hijacked-p
     poll-nmi-event poll-irq-before-clock)
  (cond
    ((%nes-boundary-nmi-taken-p nes nmi-hijacked-p)
     (if nmi-hijacked-p
         0
         (%nes-run-interrupt! nes :nmi)))
    ((%nes-irq-deliverable-p cpu irq-disabled-at-start dma-cycles
                             irq-seen-p irq-seen-before-last-p)
     (or (%nes-run-interrupt! nes :irq t poll-nmi-event
                              nil poll-irq-before-clock)
         0))
    (t 0)))
