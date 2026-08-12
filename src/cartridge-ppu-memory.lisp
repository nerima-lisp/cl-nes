(in-package #:cl-nes)

(defun cartridge-ppu-read-nametable (cartridge nametable address)
  (if (not (%cartridge-mapper5-p cartridge))
      (aref nametable (%cartridge-nametable-index cartridge address))
      (%cartridge-read-mapper5-nametable cartridge nametable address)))

(defun cartridge-ppu-write-nametable! (cartridge nametable address value)
  (if (not (%cartridge-mapper5-p cartridge))
      (setf (aref nametable (%cartridge-nametable-index cartridge address))
            value)
      (%cartridge-write-mapper5-nametable! cartridge nametable address value))
  value)

(defun cartridge-read-chr (cartridge address &optional (sprite-p t))
  (when (%cartridge-chr-address-p address)
    (let ((rom (cartridge-chr-rom cartridge)))
      (aref rom
            (mod (%cartridge-chr-offset cartridge address sprite-p)
                 (length rom))))))

(defun cartridge-write-chr! (cartridge address value)
  (when (and (cartridge-chr-writable-p cartridge)
             (%cartridge-chr-address-p address))
    (let ((rom (cartridge-chr-rom cartridge)))
      (setf (aref rom
                  (mod (%cartridge-chr-offset cartridge address) (length rom)))
            (logand value #xFF))))
  value)
