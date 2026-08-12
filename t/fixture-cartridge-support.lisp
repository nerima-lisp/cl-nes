(in-package #:cl-nes/test)

(defun make-ines-image
    (&key (prg-banks 1) (chr-banks 0)
          (flags6 0) (flags7 0) (byte8 0) (byte9 0) (byte10 0)
          trainer-p (prg-fill #xA5) (chr-fill #x5A))
  (let* ((prg-size (* prg-banks cl-nes::+prg-bank-size+))
         (chr-size (* chr-banks cl-nes::+chr-bank-size+))
         (offset (+ cl-nes::+ines-header-size+
                    (if trainer-p cl-nes::+ines-trainer-size+ 0)))
         (image (make-array (+ offset prg-size chr-size)
                            :element-type '(unsigned-byte 8)
                            :initial-element 0)))
    (setf (aref image 0) #x4E
          (aref image 1) #x45
          (aref image 2) #x53
          (aref image 3) #x1A
          (aref image 4) prg-banks
          (aref image 5) chr-banks
          (aref image 6) (if trainer-p (logior flags6 #x04) flags6)
          (aref image 7) flags7
          (aref image 8) byte8
          (aref image 9) byte9
          (aref image 10) byte10)
    (loop for index from offset below (+ offset prg-size)
          do (setf (aref image index) prg-fill))
    (loop for index from (+ offset prg-size) below (length image)
          do (setf (aref image index) chr-fill))
    image))

(defun captured-condition (thunk)
  (handler-case
      (progn (funcall thunk) nil)
    (condition (condition) condition)))

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

(defun set-fixture-vector! (cartridge address target)
  (let ((rom (cartridge-prg-rom cartridge)))
    (setf (aref rom (- address #x8000))
          (ldb (byte 8 0) target)
          (aref rom (1+ (- address #x8000)))
          (ldb (byte 8 8) target)))
  cartridge)

(defun make-banked-storage (bank-count bank-size)
  (let ((storage (make-array (* bank-count bank-size)
                             :element-type '(unsigned-byte 8))))
    (dotimes (bank bank-count storage)
      (dotimes (offset bank-size)
        (setf (aref storage (+ (* bank bank-size) offset))
              (mod bank 256))))))

(defun contract-octets (size)
  (make-array size
              :element-type '(unsigned-byte 8)
              :initial-element 0))

(defun contract-valid-prg-size (mapper)
  (cl-nes::%minimum-valid-prg-storage-size mapper))

(defun contract-valid-chr-size (mapper)
  (cl-nes::%minimum-valid-chr-storage-size mapper))

(defun make-contract-cartridge (mapper)
  (make-cartridge
   :mapper mapper
   :prg-rom (contract-octets (contract-valid-prg-size mapper))
   :chr-rom (contract-octets (contract-valid-chr-size mapper))))

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
