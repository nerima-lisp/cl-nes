(in-package #:cl-nes)

(defun %octet-vector (sequence)
  (let ((result (make-array (length sequence)
                            :element-type '(unsigned-byte 8))))
    (replace result sequence)
    result))

(defun make-cartridge (&key prg-rom chr-rom mapper mirroring
                            battery-backed-p four-screen-p chr-writable-p
                            prg-ram-size mapper4-variant)
  (setf mapper (or mapper 0)
        mirroring (or mirroring :horizontal)
        chr-writable-p (if (null chr-writable-p) (null chr-rom) chr-writable-p)
        prg-ram-size (or prg-ram-size +prg-ram-bank-size+)
        mapper4-variant (or mapper4-variant :mmc3))
  (%ensure-cartridge-options! mapper mapper4-variant prg-ram-size)
  (let ((prg (%octet-vector prg-rom))
        (chr (%coerce-chr-rom chr-rom mapper))
        (prg-ram (%make-prg-ram prg-ram-size))
        (mapper-registers (%make-mapper-registers))
        (mapper4-registers (%make-mapper4-registers))
        (mapper5-prg-banks (%make-mapper5-prg-banks))
        (mapper5-chr-banks (%make-mapper5-chr-banks))
        (mapper5-exram (%make-mapper5-exram)))
    (%validate-prg-storage! mapper prg)
    (%validate-chr-storage! mapper chr)
    (%initialize-mapper5-prg-banks! mapper prg mapper5-prg-banks)
    (%make-cartridge-state
     prg chr prg-ram mapper mirroring battery-backed-p
     four-screen-p chr-writable-p mapper-registers
     mapper4-registers mapper4-variant
     mapper5-prg-banks mapper5-chr-banks mapper5-exram)))
