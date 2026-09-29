(in-package #:cl-nes)

(defun %octet-vector (sequence)
  (let ((result (make-array (length sequence)
                            :element-type '(unsigned-byte 8))))
    (replace result sequence)
    result))

(defun make-cartridge (&key prg-rom chr-rom (mapper 0) (mirroring :horizontal)
                            battery-backed-p four-screen-p
                            (submapper 0) bus-conflict-p
                            (chr-writable-p (null chr-rom))
                            (prg-ram-size +prg-ram-bank-size+)
                            (mapper4-variant :mmc3))
  (%ensure-supported-mapper! mapper)
  (%ensure-valid-mapper4-variant! mapper4-variant)
  (%ensure-valid-prg-ram-size! prg-ram-size)
  (let ((prg (%octet-vector prg-rom))
        (chr (%octet-vector (or chr-rom (%default-chr-rom mapper))))
        (prg-ram (make-array prg-ram-size
                             :element-type '(unsigned-byte 8)
                             :initial-element 0))
        (mapper4-registers (make-array 8
                                       :element-type '(unsigned-byte 8)
                                       :initial-element 0))
        (mapper5-prg-banks (make-array 8
                                       :element-type '(unsigned-byte 8)
                                       :initial-element 0))
        (mapper5-chr-banks (make-array 12
                                       :element-type '(unsigned-byte 8)
                                       :initial-element 0))
        (mapper5-exram (make-array #x400
                                   :element-type '(unsigned-byte 8)
                                   :initial-element 0))
        (mapper-registers (make-array 8
                                      :element-type '(unsigned-byte 8)
                                      :initial-element 0))
        (mapper5-state nil))
    (%ensure-valid-prg-layout! mapper prg)
    (%initialize-mapper5-prg-banks! mapper mapper5-prg-banks prg)
    (%ensure-valid-chr-layout! mapper chr)
    (setf mapper5-state
          (%make-cartridge-mapper5-state
           :prg-mode 3
           :chr-mode 3
           :prg-banks mapper5-prg-banks
           :chr-banks mapper5-chr-banks
           :prg-ram-protect-1 0
           :prg-ram-protect-2 0
           :exram-mode 0
           :nametable-mapping 0
           :fill-tile 0
           :fill-attribute 0
           :split-control 0
           :split-scroll 0
           :split-bank 0
           :irq-scanline 0
           :irq-enabled-p nil
           :irq-pending-p nil
           :in-frame-p nil
           :multiplier-a 0
           :multiplier-b 0
           :exram mapper5-exram))
    (let ((mapper-state
            (%make-cartridge-mapper-state
             :mapper-shift #x10
             :mapper-control #x0C
             :mapper-chr-bank-0 0
             :mapper-chr-bank-1 0
             :mapper-prg-bank-1 0
             :mapper-registers mapper-registers
             :mapper-register-select 0
             :mapper-mode (if (= mapper 28)
                              (if (eq mirroring :vertical) #x0E #x0F)
                              0)
             :mapper-outer-bank #xFF))
          (mapper4-state
            (%make-cartridge-mapper4-state
             :mapper4-bank-select 0
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
             :mapper4-ppu-a12-low-cycles 0)))
      (%make-cartridge :prg-rom prg
                       :chr-rom chr
                       :prg-ram prg-ram
                       :mapper mapper
                       :mirroring mirroring
                       :initial-mirroring mirroring
                       :battery-backed-p battery-backed-p
                       :submapper submapper
                       :bus-conflict-p bus-conflict-p
                       :four-screen-p four-screen-p
                       :chr-writable-p chr-writable-p
                       :prg-bank 0
                       :chr-bank 0
                       :mapper5-state mapper5-state
                       :mapper4-state mapper4-state
                       :mapper-state mapper-state))))
