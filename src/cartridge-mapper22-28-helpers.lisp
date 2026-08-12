(in-package #:cl-nes)

(defun %merge-register-nibble (old value high-nibble-p)
  (if high-nibble-p
      (logior (logand old #x0F) (ash (logand value #x0F) 4))
      (logior (logand old #xF0) (logand value #x0F))))

(defun %mapper22-logical-low (address)
  (let ((physical-low (logand address #x03)))
    (logior (ash (logand physical-low #x01) 1)
            (ash (logand physical-low #x02) -1))))

(defun %mapper22-chr-register-index (address logical-low)
  (+ (* (floor (- (logand address #xF000) #xB000) #x1000) 2)
     (floor logical-low 2)))

(defun %mapper28-update-mirroring! (cartridge)
  (setf (cartridge-mirroring cartridge)
        (case (logand (cartridge-mapper-mode cartridge) #x03)
          (0 :single-screen-lower)
          (1 :single-screen-upper)
          (2 :vertical)
          (otherwise :horizontal))))

(defun %mapper28-write-user-mirroring! (cartridge value)
  (when (zerop (logand (cartridge-mapper-mode cartridge) #x02))
    (setf (cartridge-mapper-mode cartridge)
          (dpb (ldb (byte 1 4) value)
               (byte 1 0)
               (cartridge-mapper-mode cartridge))))
  (%mapper28-update-mirroring! cartridge))

(define-cartridge-prg-register-writers
  (%mapper22-write-prg-bank! (cartridge value)
    (setf (cartridge-prg-bank cartridge) (logand value #x1F)))

  (%mapper22-write-mirroring! (cartridge value)
    (setf (cartridge-mirroring cartridge)
          (if (logbitp 0 value) :horizontal :vertical)))

  (%mapper22-write-prg-bank-1! (cartridge value)
    (setf (cartridge-mapper-prg-bank-1 cartridge) (logand value #x1F)))

  (%mapper28-write-chr-select! (cartridge value)
    (setf (aref (cartridge-mapper-registers cartridge) 0) value
          (cartridge-chr-bank cartridge) (logand value #x03))
    (%mapper28-write-user-mirroring! cartridge value))

  (%mapper28-write-prg-select! (cartridge value)
    (setf (aref (cartridge-mapper-registers cartridge) 1) value
          (cartridge-prg-bank cartridge) (logand value #x0F))
    (%mapper28-write-user-mirroring! cartridge value))

  (%mapper28-write-mode! (cartridge value)
    (setf (cartridge-mapper-mode cartridge) (logand value #x3F))
    (%mapper28-update-mirroring! cartridge))

  (%mapper28-write-outer-bank! (cartridge value)
    (setf (cartridge-mapper-outer-bank cartridge) (logand value #x3F))))

(defun %mapper22-write-chr-bank-nibble! (cartridge address value logical-low)
  (let* ((register (%mapper22-chr-register-index address logical-low))
         (old (aref (cartridge-mapper-registers cartridge) register)))
    (setf (aref (cartridge-mapper-registers cartridge) register)
          (%merge-register-nibble old value (logbitp 0 logical-low)))))

(defun %mapper28-handle-register-write! (cartridge value)
  (case (cartridge-mapper-register-select cartridge)
    (#x00 (%mapper28-write-chr-select! cartridge value))
    (#x01 (%mapper28-write-prg-select! cartridge value))
    (#x80 (%mapper28-write-mode! cartridge value))
    (#x81 (%mapper28-write-outer-bank! cartridge value))))
