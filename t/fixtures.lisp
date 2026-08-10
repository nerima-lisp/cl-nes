(in-package #:cl-nes/test)

(defun make-fixture-cartridge (&key (program '()) (start #x8000))
  (let ((prg (make-array #x8000
                         :element-type '(unsigned-byte 8)
                         :initial-element 0)))
    (loop for byte in program
          for offset from (- start #x8000)
          do (setf (aref prg offset) byte))
    (flet ((set-vector (address target)
             (setf (aref prg (- address #x8000))
                   (ldb (byte 8 0) target)
                   (aref prg (1+ (- address #x8000)))
                   (ldb (byte 8 8) target))))
      (set-vector #xFFFC start)
      (set-vector #xFFFA start)
      (set-vector #xFFFE start))
    (make-cartridge :prg-rom prg
                    :chr-writable-p t)))

(defun make-banked-storage (bank-count bank-size)
  (let ((storage (make-array (* bank-count bank-size)
                             :element-type '(unsigned-byte 8))))
    (dotimes (bank bank-count storage)
      (dotimes (offset bank-size)
        (setf (aref storage (+ (* bank bank-size) offset))
              (mod bank 256))))))

(defun make-patterned-cartridge
    (&key mapper prg-banks chr-banks
          (prg-ram-size (* 8 cl-nes::+prg-ram-bank-size+))
          (mapper4-variant :mmc3)
          four-screen-p)
  (make-cartridge
   :prg-rom (make-banked-storage prg-banks cl-nes::+prg-bank-8k-size+)
   :chr-rom (make-banked-storage chr-banks cl-nes::+chr-bank-1k-size+)
   :mapper mapper
   :prg-ram-size prg-ram-size
   :mapper4-variant mapper4-variant
   :four-screen-p four-screen-p))
