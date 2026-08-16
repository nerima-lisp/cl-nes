(in-package #:cl-nes)

(defun ppu-reset! (ppu)
  "Reset the PPU's register, timing, and presentation state.

VRAM, palette RAM, and OAM are retained, matching the useful part of a
console reset for callers that want to preserve cartridge-backed state."
  (setf (ppu-control ppu) 0
        (ppu-mask ppu) 0
        (ppu-rendering-mask ppu) 0
        (ppu-rendering-mask-pending ppu) 0
        (ppu-rendering-mask-delay ppu) 0
        (ppu-rendering-mask-valid-p ppu) nil
        (ppu-status ppu) 0
        (ppu-oam-address ppu) 0
        (ppu-vram-address ppu) 0
        (ppu-temporary-address ppu) 0
        (ppu-fine-x ppu) 0
        (ppu-write-toggle ppu) nil
        (ppu-scroll-x ppu) 0
        (ppu-scroll-y ppu) 0
        (ppu-read-buffer ppu) 0
        (ppu-scanline ppu) 0
        (ppu-dot ppu) 0
        (ppu-frame-ready-p ppu) nil
        (ppu-odd-frame-p ppu) nil
        (ppu-nmi-pending-p ppu) nil
        (ppu-nmi-delay-p ppu) nil
        (ppu-decay-value ppu) 0
        (ppu-decay-clock ppu) 0
        (ppu-decay-next-expiry ppu) most-positive-fixnum)
  (fill (ppu-decay-deadlines ppu) most-positive-fixnum)
  (fill (ppu-framebuffer ppu) 0)
  ppu)

(defun ppu-load-cartridge! (ppu cartridge)
  (setf (ppu-cartridge ppu) cartridge)
  (when (and cartridge (cartridge-four-screen-p cartridge))
    (unless (= (length (ppu-nametable ppu)) #x1000)
      (setf (ppu-nametable ppu)
            (make-array #x1000 :element-type '(unsigned-byte 8)
                        :initial-element 0))))
  (when (and cartridge (not (cartridge-four-screen-p cartridge)))
    (unless (= (length (ppu-nametable ppu)) #x800)
      (setf (ppu-nametable ppu)
            (make-array #x800 :element-type '(unsigned-byte 8)
                        :initial-element 0))))
  (ppu-reset! ppu)
  ppu)

(defun make-ppu (&optional cartridge)
  (let ((ppu (%make-ppu)))
    (ppu-load-cartridge! ppu cartridge)
    ppu))

(defun %ppu-address-a12-high-p (address)
  (logbitp 12 (logand address #x3FFF)))

(defun %ppu-clock-address-a12! (ppu &optional (low-cycles 24))
  "Expose a CPU-visible PPU address change to the cartridge A12 detector."
  (when (ppu-cartridge ppu)
    (cartridge-clock-ppu-a12! (ppu-cartridge ppu)
                               (%ppu-address-a12-high-p
                                (ppu-vram-address ppu))
                               low-cycles)))
