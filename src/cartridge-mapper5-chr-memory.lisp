(in-package #:cl-nes)

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
