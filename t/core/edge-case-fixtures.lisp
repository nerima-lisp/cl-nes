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
