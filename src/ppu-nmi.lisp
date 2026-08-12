(in-package #:cl-nes)

(defun %request-nmi! (ppu)
  (unless (ppu-nmi-pending-p ppu)
    (setf (ppu-nmi-delay-p ppu) t))
  (setf (ppu-nmi-pending-p ppu) t)
  ppu)

(defun %cancel-nmi-delay! (ppu)
  "Cancel an NMI whose edge has not reached the CPU yet.

The PPUSTATUS read and disabling NMI both lower the PPU's NMI output.  An
NMI already observed at a CPU boundary remains pending, but the short
propagation interval represented by NMI-DELAY-P can still be suppressed."
  (when (ppu-nmi-delay-p ppu)
    (setf (ppu-nmi-delay-p ppu) nil
          (ppu-nmi-pending-p ppu) nil))
  ppu)
