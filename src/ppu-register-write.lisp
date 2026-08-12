(in-package #:cl-nes)

(defun %write-scroll! (ppu value)
  (if (not (ppu-write-toggle ppu))
      (setf (ppu-scroll-x ppu) value
            (ppu-fine-x ppu) (logand value 7)
            (ppu-temporary-address ppu)
            (logior (logand (ppu-temporary-address ppu) #x7FE0)
                    (ash value -3))
            (ppu-write-toggle ppu) t)
      (setf (ppu-scroll-y ppu) value
            (ppu-temporary-address ppu)
            (logior (logand (ppu-temporary-address ppu) #x0C1F)
                    (ash (logand value 7) 12)
                    (ash (logand value #xF8) 2))
            (ppu-write-toggle ppu) nil)))

(defun %write-address! (ppu value)
  (if (not (ppu-write-toggle ppu))
      (setf (ppu-temporary-address ppu)
            (logior (logand (ppu-temporary-address ppu) #x00FF)
                    (ash (logand value #x3F) 8))
            (ppu-write-toggle ppu) t)
      (progn
        (setf (ppu-temporary-address ppu)
              (logior (logand (ppu-temporary-address ppu) #x3F00)
                      value)
              (ppu-vram-address ppu) (ppu-temporary-address ppu)
              (ppu-write-toggle ppu) nil))))

(defun %ppu-write-control! (ppu value)
  (let ((was-enabled (logbitp 7 (ppu-control ppu))))
    (setf (ppu-control ppu) value
          (ppu-temporary-address ppu)
          (logior (logand (ppu-temporary-address ppu) #xF3FF)
                  (ash (logand value 3) 10)))
    (when (and (not was-enabled)
               (logbitp 7 value)
               (logbitp 7 (ppu-status ppu)))
      (%request-nmi! ppu))
    (when (and was-enabled
               (not (logbitp 7 value)))
      (%cancel-nmi-delay! ppu))))

(defun %ppu-write-mask! (ppu value)
  (setf (ppu-mask ppu) value
        (ppu-rendering-mask-pending ppu) value
        (ppu-rendering-mask-delay ppu) 2
        (ppu-rendering-mask-valid-p ppu) t))

(defun %ppu-write-oam-data! (ppu value)
  (setf (aref (ppu-oam ppu) (ppu-oam-address ppu)) value
        (ppu-oam-address ppu) (mod (1+ (ppu-oam-address ppu)) 256)))

(defun %ppu-write-data! (ppu value)
  (ppu-write-vram! ppu (ppu-vram-address ppu) value)
  (%ppu-vram-increment ppu)
  (%ppu-clock-address-a12! ppu))

(defun ppu-write-register! (ppu register value)
  (setf value (logand value #xFF))
  (%ppu-write-decay! ppu value
    (%ppu-write-register-dispatch register))
  value)
