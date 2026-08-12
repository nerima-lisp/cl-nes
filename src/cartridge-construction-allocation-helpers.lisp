(in-package #:cl-nes)

(defun %default-chr-size (mapper)
  (if (= mapper 28)
      (* 4 +chr-bank-size+)
      +chr-bank-size+))

(defun %make-zeroed-octet-vector (size)
  (make-array size
              :element-type '(unsigned-byte 8)
              :initial-element 0))

(defun %coerce-chr-rom (chr-rom mapper)
  (%octet-vector
   (or chr-rom
       (%make-zeroed-octet-vector (%default-chr-size mapper)))))

(defun %make-prg-ram (prg-ram-size)
  (%make-zeroed-octet-vector prg-ram-size))

(%define-octet-allocator %make-mapper-registers 8)
(%define-octet-allocator %make-mapper4-registers 8)
(%define-octet-allocator %make-mapper5-prg-banks 8)
(%define-octet-allocator %make-mapper5-chr-banks 12)
(%define-octet-allocator %make-mapper5-exram #x400)

(defun %initialize-mapper5-prg-banks! (mapper prg mapper5-prg-banks)
  (when (= mapper 5)
    (setf (aref mapper5-prg-banks 4) #x80
          (aref mapper5-prg-banks 5) #x80
          (aref mapper5-prg-banks 6) #x80
          (aref mapper5-prg-banks 7)
          (logior #x80
                  (1- (floor (length prg) +prg-bank-8k-size+)))))
  mapper5-prg-banks)

(defun %initial-mapper-mode (mapper mirroring)
  (if (= mapper 28)
      (if (eq mirroring :vertical) #x0E #x0F)
      0))

(defun %base-cartridge-initargs (prg chr prg-ram mapper mirroring battery-backed-p
                                 four-screen-p chr-writable-p mapper-registers)
  (list :prg-rom prg
        :chr-rom chr
        :prg-ram prg-ram
        :mapper mapper
        :mirroring mirroring
        :initial-mirroring mirroring
        :battery-backed-p battery-backed-p
        :four-screen-p four-screen-p
        :chr-writable-p chr-writable-p
        :prg-bank 0
        :chr-bank 0
        :mapper-shift #x10
        :mapper-control #x0C
        :mapper-chr-bank-0 0
        :mapper-chr-bank-1 0
        :mapper-prg-bank-1 0
        :mapper-registers mapper-registers
        :mapper-register-select 0
        :mapper-mode (%initial-mapper-mode mapper mirroring)
        :mapper-outer-bank #xFF))

(defun %mapper4-initargs (mapper4-registers mapper4-variant)
  (list :mapper4-bank-select 0
        :mapper4-registers mapper4-registers
        :mapper4-variant mapper4-variant
        :mapper4-prg-ram-enabled-p t
        :mapper4-prg-ram-write-protected-p nil
        :mapper4-irq-latch 0
        :mapper4-irq-counter 0
        :mapper4-irq-reload-p nil
        :mapper4-irq-enabled-p nil
        :mapper4-irq-pending-p nil
        :mapper4-ppu-a12-high-p nil
        :mapper4-ppu-a12-low-cycles 0))

(defun %mapper5-initargs (mapper5-prg-banks mapper5-chr-banks mapper5-exram)
  (list :mapper5-prg-mode 3
        :mapper5-chr-mode 3
        :mapper5-prg-banks mapper5-prg-banks
        :mapper5-chr-banks mapper5-chr-banks
        :mapper5-prg-ram-protect-1 0
        :mapper5-prg-ram-protect-2 0
        :mapper5-exram-mode 0
        :mapper5-nametable-mapping 0
        :mapper5-fill-tile 0
        :mapper5-fill-attribute 0
        :mapper5-split-control 0
        :mapper5-split-scroll 0
        :mapper5-split-bank 0
        :mapper5-irq-scanline 0
        :mapper5-irq-enabled-p nil
        :mapper5-irq-pending-p nil
        :mapper5-in-frame-p nil
        :mapper5-multiplier-a 0
        :mapper5-multiplier-b 0
        :mapper5-exram mapper5-exram))

(defun %make-cartridge-state (prg chr prg-ram mapper mirroring battery-backed-p
                              four-screen-p chr-writable-p mapper-registers
                              mapper4-registers mapper4-variant
                              mapper5-prg-banks mapper5-chr-banks mapper5-exram)
  (apply #'%make-cartridge
         (append (%base-cartridge-initargs
                  prg chr prg-ram mapper mirroring battery-backed-p
                  four-screen-p chr-writable-p mapper-registers)
                 (%mapper4-initargs mapper4-registers mapper4-variant)
                 (%mapper5-initargs
                  mapper5-prg-banks mapper5-chr-banks mapper5-exram))))
