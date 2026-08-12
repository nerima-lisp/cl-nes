(in-package #:cl-nes)

(defun %ppu-reset-register-state! (ppu)
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
        (ppu-nmi-delay-p ppu) nil))

(defun %ppu-reset-decay-state! (ppu)
  (setf (ppu-decay-value ppu) 0
        (ppu-decay-clock ppu) 0
        (ppu-decay-next-expiry ppu) most-positive-fixnum)
  (fill (ppu-decay-deadlines ppu) most-positive-fixnum))

(defun %ppu-reset-presentation-state! (ppu)
  (fill (ppu-framebuffer ppu) 0))

(defun %ppu-resize-nametable-if-needed! (ppu size)
  (unless (= (length (ppu-nametable ppu)) size)
    (setf (ppu-nametable ppu)
          (make-array size :element-type '(unsigned-byte 8)
                      :initial-element 0))))

(defun %ppu-configure-cartridge-memory! (ppu cartridge)
  (setf (ppu-cartridge ppu) cartridge)
  (when cartridge
    (%ppu-resize-nametable-if-needed!
     ppu
     (if (cartridge-four-screen-p cartridge)
         #x1000
         #x800))))
