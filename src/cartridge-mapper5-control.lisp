(in-package #:cl-nes)

(define-register-write-dispatch-from-table
    %mapper5-write-expansion! (cartridge address value)
    +mapper5-expansion-write-register-specs+
  ((= address #x5204)
   (setf (cartridge-mapper5-irq-enabled-p cartridge) (logbitp 7 value))
   (unless (logbitp 7 value)
     (setf (cartridge-mapper5-irq-pending-p cartridge) nil)))
  ((<= #x5113 address #x5117)
   (setf (aref (cartridge-mapper5-prg-banks cartridge)
               (- address #x5110))
         value))
  ((<= #x5120 address #x512B)
   (setf (aref (cartridge-mapper5-chr-banks cartridge)
               (- address #x5120))
         value))
  ((and (<= #x5C00 address #x5FFF)
        (/= (cartridge-mapper5-exram-mode cartridge) 3))
   (cartridge-mmc5-write-exram! cartridge (- address #x5C00) value)))

(define-register-read-dispatch-from-table
    %mapper5-read-expansion (cartridge address)
    +mapper5-expansion-read-register-specs+
  ((= address #x5204)
   (prog1 (logior (if (cartridge-mapper5-irq-pending-p cartridge)
                      #x80
                      0)
                  (if (cartridge-mapper5-in-frame-p cartridge)
                      #x40
                      0))
     (setf (cartridge-mapper5-irq-pending-p cartridge) nil)))
  ((and (<= #x5C00 address #x5FFF)
        (/= (cartridge-mapper5-exram-mode cartridge) 3))
   (cartridge-mmc5-read-exram cartridge (- address #x5C00))))

(defun cartridge-read-expansion (cartridge address)
  (when (= (cartridge-mapper cartridge) 5)
    (%mapper5-read-expansion cartridge address)))

(defun cartridge-write-expansion! (cartridge address value)
  (when (= (cartridge-mapper cartridge) 5)
    (%mapper5-write-expansion! cartridge address value))
  value)
