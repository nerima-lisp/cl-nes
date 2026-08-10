(in-package #:cl-nes)

(defconstant +ppu-width+ 256)
(defconstant +ppu-height+ 240)
(defconstant +ppu-vram-size+ #x4000)

(defstruct (ppu
            (:constructor %make-ppu
                (&key cartridge control mask status oam-address oam nametable
                      palette vram-address temporary-address fine-x write-toggle
                      scroll-x scroll-y read-buffer scanline dot frame-ready-p
                      odd-frame-p nmi-pending-p nmi-delay-p decay-value decay-clock
                      decay-deadlines decay-next-expiry rendering-mask
                      rendering-mask-pending rendering-mask-delay
                      rendering-mask-valid-p framebuffer)))
  (cartridge nil)
  (control 0 :type (unsigned-byte 8))
  (mask 0 :type (unsigned-byte 8))
  ;; PPUMASK writes reach the rendering pipeline after a short propagation
  ;; delay.  MASK remains the CPU-visible register; these fields hold the
  ;; effective value used by timing-sensitive behavior.
  (rendering-mask 0 :type (unsigned-byte 8))
  (rendering-mask-pending 0 :type (unsigned-byte 8))
  (rendering-mask-delay 0 :type fixnum)
  (rendering-mask-valid-p nil)
  (status 0 :type (unsigned-byte 8))
  (oam-address 0 :type (unsigned-byte 8))
  (oam (make-array 256 :element-type '(unsigned-byte 8) :initial-element 0)
       :type vector)
  (nametable (make-array 2048 :element-type '(unsigned-byte 8) :initial-element 0)
             :type vector)
  (palette (make-array 32 :element-type '(unsigned-byte 8) :initial-element 0)
           :type vector)
  (vram-address 0 :type fixnum)
  (temporary-address 0 :type fixnum)
  (fine-x 0 :type fixnum)
  (write-toggle nil)
  (scroll-x 0 :type fixnum)
  (scroll-y 0 :type fixnum)
  (read-buffer 0 :type (unsigned-byte 8))
  (scanline 0 :type fixnum)
  (dot 0 :type fixnum)
  (frame-ready-p nil)
  (odd-frame-p nil)
  (nmi-pending-p nil)
  (nmi-delay-p nil)
  (decay-value 0 :type (unsigned-byte 8))
  (decay-clock 0 :type fixnum)
  (decay-deadlines (make-array 8 :initial-element 0) :type vector)
  (decay-next-expiry most-positive-fixnum :type fixnum)
  (framebuffer (make-array (* +ppu-width+ +ppu-height+)
                           :element-type '(unsigned-byte 8)
                           :initial-element 0)
               :type vector))
