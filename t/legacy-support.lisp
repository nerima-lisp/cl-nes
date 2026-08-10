(in-package #:cl-nes/test-runner)

(defun make-test-cartridge (&key (program '()) (start #x8000)
                                   (reset #x8000) (nmi #x8000) (irq #x8000))
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
      (set-vector #xFFFC reset)
      (set-vector #xFFFA nmi)
      (set-vector #xFFFE irq))
      (make-cartridge :prg-rom prg
                      :chr-writable-p t)))

(defun make-banked-rom (bank-count bank-size &optional (value-offset 0))
  (let ((rom (make-array (* bank-count bank-size)
                         :element-type '(unsigned-byte 8))))
    (dotimes (bank bank-count rom)
      (fill rom (+ value-offset bank)
            :start (* bank bank-size)
            :end (* (1+ bank) bank-size)))))


