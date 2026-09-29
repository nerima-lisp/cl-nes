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

(defmacro with-fixture-ppu ((name &optional cartridge-form) &body body)
  "Bind NAME to a fresh PPU backed by an optional fixture cartridge."
  `(let ((,name (make-ppu ,cartridge-form)))
     ,@body))
