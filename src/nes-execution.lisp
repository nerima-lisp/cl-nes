(in-package #:cl-nes)

(defun nes-step/k (nes continuation)
  "Run one NES step and pass its CPU-cycle count to CONTINUATION.

The continuation is called after instruction, DMA, and interrupt clocks have
been applied.  The function returns the continuation's result."
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
               nes #'poll-nmi-event nil #'poll-irq-before-clock)))
        (let ((dma-cycles (bus-take-dma-stall-cycles! (nes-bus nes))))
          (when (plusp dma-cycles)
            (incf cycles
                  (%nes-run-dma-stalls! nes dma-cycles
                                         #'poll-irq-before-clock)))
          ;; NMI is sampled before maskable IRQ, matching the 6502 priority.
          (incf cycles
                (%nes-run-post-instruction-interrupts!
                 nes cpu irq-disabled-at-start dma-cycles
                 irq-seen-p irq-seen-before-last-p nmi-hijacked-p
                 #'poll-nmi-event #'poll-irq-before-clock))
          ;; CLI/SEI/PLP delay IRQ recognition for the following instruction.
          (when (plusp (cpu-irq-delay cpu))
            (decf (cpu-irq-delay cpu)))
          (funcall continuation cycles))))))

(defun nes-run-frame/k (nes continuation)
  "Run until a frame is ready and pass its framebuffer to CONTINUATION."
  (setf (ppu-frame-ready-p (nes-ppu nes)) nil)
  (loop until (ppu-frame-ready-p (nes-ppu nes))
        do (nes-step/k nes #'identity))
  (funcall continuation (ppu-framebuffer (nes-ppu nes))))
