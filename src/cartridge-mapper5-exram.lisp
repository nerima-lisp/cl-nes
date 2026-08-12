(in-package #:cl-nes)

(defun %cartridge-mmc5-exram-index (address)
  (mod address #x400))

(defun cartridge-mmc5-read-exram (cartridge within)
  (aref (cartridge-mapper5-exram cartridge)
        (%cartridge-mmc5-exram-index within)))

(defun cartridge-mmc5-write-exram! (cartridge within value)
  (setf (aref (cartridge-mapper5-exram cartridge)
              (%cartridge-mmc5-exram-index within))
        value)
  value)

(defun cartridge-mmc5-nametable-location (cartridge address)
  (when (= (cartridge-mapper cartridge) 5)
    (let* ((offset (mod (- address #x2000) #x1000))
           (table (floor offset #x400))
           (within (mod offset #x400))
           (source (ldb (byte 2 (* table 2))
                        (cartridge-mapper5-nametable-mapping cartridge))))
      (values (case source
                (0 :ciram-0)
                (1 :ciram-1)
                (2 :exram)
                (otherwise :fill))
              within))))

(defun cartridge-mmc5-fill-value (cartridge within)
  (if (< within #x3C0)
      (cartridge-mapper5-fill-tile cartridge)
      (let ((attribute (cartridge-mapper5-fill-attribute cartridge)))
        (logior attribute
                (ash attribute 2)
                (ash attribute 4)
                (ash attribute 6)))))
