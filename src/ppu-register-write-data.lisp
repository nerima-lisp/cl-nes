(in-package #:cl-nes)

(defparameter +ppu-register-write-dispatch-forms+
  '((0 (%ppu-write-control! ppu value))
    (1 (%ppu-write-mask! ppu value))
    (3 (setf (ppu-oam-address ppu) value))
    (4 (%ppu-write-oam-data! ppu value))
    (5 (%write-scroll! ppu value))
    (6 (%write-address! ppu value)
       (unless (ppu-write-toggle ppu)
         (%ppu-clock-address-a12! ppu)))
    (7 (%ppu-write-data! ppu value))))
