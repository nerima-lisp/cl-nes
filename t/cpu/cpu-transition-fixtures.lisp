(in-package #:cl-nes/test)

(defun set-fixture-vector! (cartridge address target)
  (let ((rom (cartridge-prg-rom cartridge)))
    (setf (aref rom (- address #x8000))
          (ldb (byte 8 0) target)
          (aref rom (1+ (- address #x8000)))
          (ldb (byte 8 8) target)))
  cartridge)
