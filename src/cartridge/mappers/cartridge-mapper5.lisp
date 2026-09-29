(in-package #:cl-nes)

(defun %mapper5-prg-bank (cartridge slot)
  (let ((registers (cartridge-mapper5-prg-banks cartridge)))
    (case (cartridge-mapper5-prg-mode cartridge)
      (0
       (values (+ (logand (aref registers 7) #x7C) slot) 7))
      (1
       (if (< slot 2)
           (values (+ (logand (aref registers 5) #x7E) (mod slot 2)) 5)
           (values (+ (logand (aref registers 7) #x7E) (mod slot 2)) 7)))
      (2
       (cond
         ((< slot 2)
          (values (+ (logand (aref registers 5) #x7E) (mod slot 2)) 5))
         ((= slot 2) (values (logand (aref registers 6) #x7F) 6))
         (t (values (logand (aref registers 7) #x7F) 7))))
      (otherwise
       (values (logand (aref registers (+ 4 slot)) #x7F) (+ 4 slot))))))

(defun %mapper5-read-prg (cartridge address)
  (let ((slot (floor (- address #x8000) +prg-bank-8k-size+)))
    (multiple-value-bind (bank register)
        (%mapper5-prg-bank cartridge slot)
      (let* ((register-value (aref (cartridge-mapper5-prg-banks cartridge)
                                   register))
             (offset (+ (* bank +prg-bank-8k-size+)
                        (mod (- address #x8000) +prg-bank-8k-size+)))
             (storage (if (or (= register 7)
                              (logbitp 7 register-value))
                          (cartridge-prg-rom cartridge)
                          (cartridge-prg-ram cartridge))))
        (when (plusp (length storage))
          (aref storage (mod offset (length storage))))))))

(defun %mapper5-write-mapped-prg! (cartridge address value)
  (let ((slot (floor (- address #x8000) +prg-bank-8k-size+)))
    (multiple-value-bind (bank register)
        (%mapper5-prg-bank cartridge slot)
      (let ((register-value
              (aref (cartridge-mapper5-prg-banks cartridge) register)))
        (when (and (zerop (logand register-value #x80))
                   (= (logand (cartridge-mapper5-prg-ram-protect-1 cartridge)
                              3)
                      2)
                   (= (logand (cartridge-mapper5-prg-ram-protect-2 cartridge)
                              3)
                      1)
                   (plusp (length (cartridge-prg-ram cartridge))))
          (setf (aref (cartridge-prg-ram cartridge)
                      (mod (+ (* bank +prg-bank-8k-size+)
                              (mod (- address #x8000) +prg-bank-8k-size+))
                           (length (cartridge-prg-ram cartridge))))
                (logand value #xFF))))))
  value)

(defun %mapper5-chr-offset (cartridge address sprite-p)
  (let* ((slot (floor address +chr-bank-1k-size+))
         (banks (cartridge-mapper5-chr-banks cartridge))
         (register 0)
         (local-slot slot))
    (case (cartridge-mapper5-chr-mode cartridge)
      (0
       (setf register (if sprite-p 7 11)
             local-slot slot)
       (setf (aref banks register) (logand (aref banks register) #xFF)))
      (1
       (if sprite-p
           (setf register (if (< slot 4) 3 7)
                 local-slot (mod slot 4))
           (setf register 11
                 local-slot (mod slot 4))))
      (2
       (if sprite-p
           (setf register (cond ((< slot 2) 2)
                                ((< slot 4) 4)
                                ((< slot 6) 6)
                                (t 7))
                 local-slot (mod slot 2))
           (setf register (if (< slot 2) 10 11)
                  local-slot (mod slot 2))))
      (otherwise
       (setf register (if sprite-p slot (+ 8 (mod slot 4)))
             local-slot 0)))
    (+ (* (case (cartridge-mapper5-chr-mode cartridge)
            (0 (logand (aref banks register) #xF8))
            (1 (logand (aref banks register) #xFC))
            (2 (logand (aref banks register) #xFE))
            (otherwise (aref banks register)))
          +chr-bank-1k-size+)
       (* local-slot +chr-bank-1k-size+)
       (mod address +chr-bank-1k-size+))))

(defun %mapper5-prg-ram-offset (cartridge address)
  (+ (* (logand (aref (cartridge-mapper5-prg-banks cartridge) 3) 7)
         +prg-ram-bank-size+)
     (- address #x6000)))

(defun %mapper5-prg-ram-writable-p (cartridge)
  (and (= (logand (cartridge-mapper5-prg-ram-protect-1 cartridge) 3) 2)
       (= (logand (cartridge-mapper5-prg-ram-protect-2 cartridge) 3) 1)))

(defun cartridge-irq-pending-p (cartridge)
  (and cartridge
       (or (and (= (cartridge-mapper cartridge) 4)
                (cartridge-mapper4-irq-pending-p cartridge))
           (and (= (cartridge-mapper cartridge) 5)
                (cartridge-mapper5-state-irq-pending-p
                 (cartridge-mapper5-state cartridge)))
           (and (= (cartridge-mapper cartridge) 69)
                (cartridge-mapper69-irq-pending-p cartridge)))))
