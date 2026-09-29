(in-package #:cl-nes)

(defvar *nes-step-context* nil)

(defun %nes-poll-irq-before-clock! (nes)
  (let ((irq-pending-p (%nes-irq-pending-p nes)))
    (setf (nes-irq-seen-before-last-p nes) irq-pending-p
          (nes-irq-seen-p nes) irq-pending-p)))

(defun %nes-poll-irq-before-cycle! ()
  (%nes-poll-irq-before-clock! *nes-step-context*))

(defun %nes-poll-nmi-event! ()
  (let ((nes *nes-step-context*))
    (when (%nes-poll-nmi-during-operation! nes)
      (setf (nes-nmi-hijacked-p nes) t)
      t)))

(defun %nes-run-instruction! (nes &optional cycle-hook pre-cycle-hook)
  (with-nes-cpu-operation (nes cycle-hook pre-cycle-hook)
    (cpu-step! (nes-cpu nes) (nes-bus nes) #'%nes-poll-nmi-event!)))

(defun %nes-run-interrupt! (nes type &optional brk-p cycle-hook
                                          pre-cycle-hook)
  (with-nes-cpu-operation (nes cycle-hook pre-cycle-hook)
    (cpu-interrupt! (nes-cpu nes) (nes-bus nes) type brk-p
                    #'%nes-poll-nmi-event!)))

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
         (not (%nmi-delay-active-p ppu))
         (ppu-take-nmi! ppu))))

(defun %nes-poll-nmi-during-operation! (nes)
  "Consume an NMI at an interrupt-response vector polling point.

The PPU models the short propagation delay separately from the pending edge.
At the CPU's vector polling point both states are observable: the first read
advances a delayed edge to the CPU, and the following poll consumes it."
  (%nes-take-nmi! nes))

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
    (setf (nes-irq-seen-p nes) irq-seen-p
          (nes-irq-seen-before-last-p nes) irq-seen-before-last-p
          (nes-nmi-hijacked-p nes) nmi-hijacked-p)
    (let ((*nes-step-context* nes))
      (let ((cycles
              (%nes-run-instruction!
               nes cycle-hook #'%nes-poll-irq-before-cycle!)))
        (let ((dma-cycles (bus-take-dma-stall-cycles! (nes-bus nes))))
          (when (plusp dma-cycles)
            (incf cycles
                  (%nes-run-dma-stalls! nes dma-cycles
                                         cycle-hook)))
          ;; NMI is sampled before maskable IRQ, matching the 6502 priority.
          (let ((nmi-taken-p
                  (or (nes-nmi-hijacked-p nes)
                      (ppu-take-nmi! (nes-ppu nes)))))
            (when (and nmi-taken-p (not (nes-nmi-hijacked-p nes)))
              (incf cycles (%nes-run-interrupt!
                            nes :nmi nil cycle-hook nil)))
            (when (and (not nmi-taken-p)
                       (zerop dma-cycles)
                       (%nes-irq-eligible-p cpu irq-disabled-at-start)
                       (nes-irq-seen-before-last-p nes))
              (let ((interrupt-cycles
                      (%nes-run-interrupt!
                       nes :irq t cycle-hook #'%nes-poll-irq-before-cycle!)))
                (when interrupt-cycles
                  (incf cycles interrupt-cycles)))))
          ;; CLI/SEI/PLP delay IRQ recognition for the following instruction.
          (when (plusp (cpu-irq-delay cpu))
            (decf (cpu-irq-delay cpu)))
          (funcall continuation cycles))))))

(defun nes-run-frame/k (nes continuation &key cycle-hook input-continuation)
  "Run until a frame is ready and pass its framebuffer to CONTINUATION.

CYCLE-HOOK, when supplied, is forwarded to NES-STEP/K for every CPU cycle.
INPUT-CONTINUATION, when supplied, is called once with NES before the frame's
first CPU step, allowing live controller state to be updated at a frame
boundary."
  (when input-continuation
    (unless (functionp input-continuation)
      (error "Input continuation must be a function: ~S" input-continuation)))
  (setf (ppu-frame-ready-p (nes-ppu nes)) nil)
  (when input-continuation
    (funcall input-continuation nes))
  (loop until (ppu-frame-ready-p (nes-ppu nes))
        do (nes-step/k nes #'identity :cycle-hook cycle-hook))
  (funcall continuation (ppu-framebuffer (nes-ppu nes))))
