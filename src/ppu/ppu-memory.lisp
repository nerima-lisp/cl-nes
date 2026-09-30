(in-package #:cl-nes)

(defun %ppu-address (address)
  (mod address +ppu-vram-size+))

(defun %palette-index (address)
  (let ((index (mod (- address #x3F00) #x20)))
    (if (member index '(#x10 #x14 #x18 #x1C))
        (- index #x10)
        index)))

(defun %ppu-nametable-address (address)
  (if (>= address #x3000)
      (- address #x1000)
      address))

(declaim (inline %ppu-address-bus!))

(defun %ppu-read-nametable (ppu address)
  (cartridge-ppu-read-nametable
   (ppu-cartridge ppu)
   (ppu-nametable ppu)
   (%ppu-nametable-address address)))

(defun %ppu-write-nametable! (ppu address value)
  (cartridge-ppu-write-nametable!
   (ppu-cartridge ppu)
   (ppu-nametable ppu)
   (%ppu-nametable-address address)
   value))

(defun %ppu-address-bus! (ppu address)
  (let ((address (%ppu-address address)))
    (when (ppu-a12-clock-enabled-p ppu)
      (let ((previous-address (ppu-address-bus ppu))
            (a12 (logand address #x1000)))
        (when (/= (logand previous-address #x1000) a12)
          (cartridge-clock-ppu-a12! (ppu-cartridge ppu) (plusp a12)))))
    (setf (ppu-address-bus ppu) address)))

(defun ppu-read-vram (ppu address &optional (sprite-p nil) (bus-access-p nil))
  (when bus-access-p
    (%ppu-address-bus! ppu address))
  (let ((address (%ppu-address address)))
    (cond
      ((< address #x2000)
       (if (ppu-cartridge ppu)
           (or (cartridge-read-chr (ppu-cartridge ppu) address sprite-p) 0)
           0))
      ((< address #x3F00)
       (%ppu-read-nametable ppu address))
      (t
       (aref (ppu-palette ppu) (%palette-index address))))))

(defun ppu-write-vram! (ppu address value &optional (bus-access-p nil))
  (when bus-access-p
    (%ppu-address-bus! ppu address))
  (let ((address (%ppu-address address))
        (value (logand value #xFF)))
    (cond
      ((< address #x2000)
       (when (ppu-cartridge ppu)
         (cartridge-write-chr! (ppu-cartridge ppu) address value)))
      ((< address #x3F00)
       (%ppu-write-nametable! ppu address value))
      (t
       (setf (aref (ppu-palette ppu) (%palette-index address)) value)))
    value))

(defun %ppu-vram-increment (ppu)
  (incf (ppu-vram-address ppu) (if (logbitp 2 (ppu-control ppu)) 32 1))
  (setf (ppu-vram-address ppu) (%ppu-address (ppu-vram-address ppu)))
  (ppu-vram-address ppu))
