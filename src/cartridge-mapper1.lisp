(in-package #:cl-nes)

(defun %mapper1-update-mirroring! (cartridge)
  (setf (cartridge-mirroring cartridge)
        (case (logand (cartridge-mapper-control cartridge) #x03)
          (0 :single-screen-lower)
          (1 :single-screen-upper)
          (2 :vertical)
          (otherwise :horizontal))))

(defun %mapper1-commit! (cartridge address value)
  (case (logand address #x6000)
    (#x0000
     (setf (cartridge-mapper-control cartridge) value)
     (%mapper1-update-mirroring! cartridge))
    (#x2000
     (setf (cartridge-mapper-chr-bank-0 cartridge) value))
    (#x4000
     (setf (cartridge-mapper-chr-bank-1 cartridge) value))
    (otherwise
     (setf (cartridge-prg-bank cartridge) value))))

(defun %mapper1-write! (cartridge address value)
  (cond
    ((logbitp 7 value)
     (setf (cartridge-mapper-shift cartridge) #x10
           (cartridge-mapper-control cartridge)
           (logior (cartridge-mapper-control cartridge) #x0C))
     (%mapper1-update-mirroring! cartridge))
    ((logbitp 0 (cartridge-mapper-shift cartridge))
     (let ((shift (logior (ash (cartridge-mapper-shift cartridge) -1)
                          (ash (logand value 1) 4))))
       (%mapper1-commit! cartridge address shift)
       (setf (cartridge-mapper-shift cartridge) #x10)))
    (t
     (setf (cartridge-mapper-shift cartridge)
           (logior (ash (cartridge-mapper-shift cartridge) -1)
                   (ash (logand value 1) 4)))))
  value)

(defun %mapper1-prg-offset (cartridge address)
  (let* ((offset (- address #x8000))
         (bank-count (floor (length (cartridge-prg-rom cartridge))
                            +prg-bank-size+))
         (mode (ldb (byte 2 2) (cartridge-mapper-control cartridge)))
         (selected-bank (cartridge-prg-bank cartridge)))
    (cond
      ((<= mode 1)
       (let ((bank (logand selected-bank #x0E)))
         (+ (* (mod bank bank-count) +prg-bank-size+)
            offset)))
      ((= mode 2)
       (+ (* (if (< offset +prg-bank-size+)
                 0
                 (mod selected-bank bank-count))
             +prg-bank-size+)
          (mod offset +prg-bank-size+)))
      (t
       (+ (* (if (< offset +prg-bank-size+)
                 (mod selected-bank bank-count)
                 (1- bank-count))
             +prg-bank-size+)
          (mod offset +prg-bank-size+))))))

(defun %mapper1-chr-offset (cartridge address)
  (let ((chr (cartridge-chr-rom cartridge))
        (control (cartridge-mapper-control cartridge)))
    (if (logbitp 4 control)
        (let ((bank (if (< address #x1000)
                        (cartridge-mapper-chr-bank-0 cartridge)
                        (cartridge-mapper-chr-bank-1 cartridge))))
          (+ (* (mod bank (floor (length chr) +chr-bank-4k-size+))
                +chr-bank-4k-size+)
             (mod address +chr-bank-4k-size+)))
        (+ (* (mod (logand (cartridge-mapper-chr-bank-0 cartridge) #x1E)
                   (floor (length chr) +chr-bank-size+))
                +chr-bank-size+)
           (mod address +chr-bank-size+)))))


