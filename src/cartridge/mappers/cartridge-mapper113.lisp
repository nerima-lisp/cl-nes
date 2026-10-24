(in-package #:cl-nes)

(defun %mapper113-prg-offset (cartridge address)
  (let* ((bank-size (* 2 +prg-bank-size+))
         (bank-count (floor (length (cartridge-prg-rom cartridge)) bank-size))
         (bank (mod (cartridge-prg-bank cartridge) bank-count)))
    (+ (* bank bank-size)
       (mod (- address #x8000) bank-size))))

(defun %mapper113-chr-offset (cartridge address)
  (let* ((bank-count (floor (length (cartridge-chr-rom cartridge))
                            +chr-bank-size+))
         (bank (mod (cartridge-chr-bank cartridge) bank-count)))
    (+ (* bank +chr-bank-size+)
       (mod address +chr-bank-size+))))

(defun %mapper113-register-address-p (address)
  (= (logand address #xE100) #x4100))

(defun %mapper113-write! (cartridge address value)
  (when (%mapper113-register-address-p address)
    (set-cartridge-prg-bank! cartridge (ldb (byte 3 3) value))
    (set-cartridge-chr-bank!
     cartridge
     (logior (ldb (byte 3 0) value)
             (ash (ldb (byte 1 6) value) 3)))
    (unless (cartridge-four-screen-p cartridge)
      (set-cartridge-mirroring!
       cartridge
       (if (logbitp 7 value) :vertical :horizontal))))
  value)
