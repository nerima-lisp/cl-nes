(in-package #:cl-nes)

(defun ppu-reset! (ppu)
  "Reset the PPU's register, timing, and presentation state.

VRAM, palette RAM, and OAM are retained, matching the useful part of a
console reset for callers that want to preserve cartridge-backed state."
  (%ppu-reset-register-state! ppu)
  (%ppu-reset-decay-state! ppu)
  (%ppu-reset-presentation-state! ppu)
  ppu)

(defun ppu-load-cartridge! (ppu cartridge)
  (%ppu-configure-cartridge-memory! ppu cartridge)
  (ppu-reset! ppu)
  ppu)

(defun make-ppu (&optional cartridge)
  (let ((ppu (%make-ppu)))
    (ppu-load-cartridge! ppu cartridge)
    ppu))

(defun %ppu-address-a12-high-p (address)
  (logbitp 12 (logand address #x3FFF)))

(defun %ppu-clock-address-a12! (ppu)
  "Expose explicit PPU address-bus changes to MMC3's A12 detector.

The renderer supplies the normal fetch phase, but CPU-visible $2006/$2007
accesses also change the PPU address bus.  Those accesses are used by the
MMC3 test ROMs to exercise the edge detector while rendering is disabled."
  (when (ppu-cartridge ppu)
    ;; A CPU register access leaves the line low for the full MMC3 filter
    ;; window before a subsequent high address is observed.
    (cartridge-clock-ppu-a12! (ppu-cartridge ppu)
                               (%ppu-address-a12-high-p
                                (ppu-vram-address ppu))
                               24)))
