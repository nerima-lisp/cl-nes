(in-package #:cl-nes/test)

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
          (submapper 0)
          four-screen-p)
  (make-cartridge
   :prg-rom (make-banked-storage prg-banks cl-nes::+prg-bank-8k-size+)
   :chr-rom (make-banked-storage chr-banks cl-nes::+chr-bank-1k-size+)
   :mapper mapper
   :submapper submapper
   :prg-ram-size prg-ram-size
   :mapper4-variant mapper4-variant
   :four-screen-p four-screen-p))

(defmacro with-patterned-cartridge ((name &rest initargs) &body body)
  "Bind NAME to a patterned cartridge configured from INITARGS."
  `(let ((,name (make-patterned-cartridge ,@initargs)))
     ,@body))

(defmacro with-patterned-cartridges (bindings &body body)
  "Bind multiple patterned cartridges from BINDINGS."
  (labels ((expand-bindings (remaining forms)
             (if (endp remaining)
                 `(progn ,@forms)
                 `(with-patterned-cartridge ,(first remaining)
                    ,(expand-bindings (rest remaining) forms)))))
    (expand-bindings bindings body)))
