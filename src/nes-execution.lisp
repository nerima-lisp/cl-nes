(in-package #:cl-nes)

(defun %nes-run-instruction! (nes)
  (with-nes-cpu-operation (nes)
    (cpu-step! (nes-cpu nes) (nes-bus nes))))

(defun %nes-run-interrupt! (nes type &optional brk-p)
  (with-nes-cpu-operation (nes)
    (cpu-interrupt! (nes-cpu nes) (nes-bus nes) type brk-p)))

(defun %nes-irq-eligible-p (cpu irq-disabled-at-start)
  (if (plusp (cpu-irq-delay cpu))
      (not irq-disabled-at-start)
      (not (%flag-set-p cpu +flag-interrupt-disable+))))

(defun %nes-cartridge-irq-pending-p (nes)
  (let ((cartridge (bus-cartridge (nes-bus nes))))
    (and cartridge
         (cartridge-irq-pending-p cartridge))))

(defun nes-step/k (nes continuation)
  "Run one NES step and pass its CPU-cycle count to CONTINUATION.

The continuation is called after instruction, DMA, and interrupt clocks have
been applied.  The function returns the continuation's result."
  (let* ((cpu (nes-cpu nes))
         (irq-disabled-at-start
           (%flag-set-p cpu +flag-interrupt-disable+))
         (cycles (%nes-run-instruction! nes)))
    (let ((dma-cycles (bus-take-dma-stall-cycles! (nes-bus nes))))
      (when (plusp dma-cycles)
        (incf cycles dma-cycles)
        (%nes-tick! nes dma-cycles)))
    ;; NMI is sampled before maskable IRQ, matching the 6502 priority.
    (let ((nmi-taken-p (ppu-take-nmi! (nes-ppu nes))))
      (when nmi-taken-p
        (incf cycles (%nes-run-interrupt! nes :nmi)))
      (when (and (not nmi-taken-p)
                 (%nes-irq-eligible-p cpu irq-disabled-at-start)
                 (or (apu-irq-pending-p (nes-apu nes))
                     (%nes-cartridge-irq-pending-p nes)))
        (let ((interrupt-cycles (%nes-run-interrupt! nes :irq t)))
          (when interrupt-cycles
            (incf cycles interrupt-cycles)))))
    ;; CLI/SEI/PLP delay IRQ recognition for the following instruction.
    (when (plusp (cpu-irq-delay cpu))
      (decf (cpu-irq-delay cpu)))
    (funcall continuation cycles)))

(defun nes-run-frame/k (nes continuation)
  "Run until a frame is ready and pass its framebuffer to CONTINUATION."
  (setf (ppu-frame-ready-p (nes-ppu nes)) nil)
  (loop until (ppu-frame-ready-p (nes-ppu nes))
        do (nes-step/k nes #'identity))
  (funcall continuation (ppu-framebuffer (nes-ppu nes))))
