(in-package #:cl-nes)

(defun %ppu-read-status-register (ppu bus-access-p)
  (let* ((decay (%ppu-current-decay ppu))
         (value (if bus-access-p
                    (logior (logand (ppu-status ppu) #xE0)
                            (logand decay #x1F))
                    (ppu-status ppu))))
    (%ppu-drive-decay! ppu value #xE0)
    (prog1 value
      (setf (ppu-status ppu) (logand (ppu-status ppu) #x7F)
            (ppu-write-toggle ppu) nil)
      (when (and (= (ppu-scanline ppu) 241)
                 (zerop (ppu-dot ppu)))
        (setf (ppu-vblank-suppression-p ppu) t))
      (if (%nmi-suppression-window-p ppu)
          (%cancel-nmi-delay! ppu)
          (when (and (logbitp 7 value)
                     (ppu-nmi-pending-p ppu)
                     (%nmi-delay-active-p ppu))
            (setf (ppu-nmi-delay-p ppu) 0))))))

(defun %ppu-read-oam-data-register (ppu bus-access-p)
  (let* ((raw (aref (ppu-oam ppu) (ppu-oam-address ppu)))
         (value (if (and bus-access-p
                         (= (logand (ppu-oam-address ppu) 3) 2))
                    (logand raw #xE3)
                    raw)))
    (%ppu-drive-decay! ppu value)
    value))

(defun %ppu-read-data-register (ppu)
  (let* ((address (ppu-vram-address ppu))
         (palette-p (>= (logand address #x3FFF) #x3F00))
         (value (ppu-read-vram ppu address nil t))
         (decay (%ppu-current-decay ppu))
         (result (if palette-p
                     (logior (logand value #x3F)
                             (logand decay #xC0))
                     (ppu-read-buffer ppu))))
    (%ppu-drive-decay! ppu result (if palette-p #x3F #xFF))
    (prog1 result
      (setf (ppu-read-buffer ppu)
            (if palette-p
                (ppu-read-vram ppu (- address #x1000) nil t)
                value))
      (%ppu-vram-increment ppu)
      (%ppu-address-bus! ppu (ppu-vram-address ppu)))))

(defun ppu-read-register (ppu register &optional bus-access-p)
  (case (logand register 7)
    (2 (%ppu-read-status-register ppu bus-access-p))
    (4 (%ppu-read-oam-data-register ppu bus-access-p))
    (7 (%ppu-read-data-register ppu))
    (otherwise (if bus-access-p
                   (%ppu-current-decay ppu)
                   0))))

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
      (setf (ppu-temporary-address ppu)
            (logior (logand (ppu-temporary-address ppu) #x3F00) value)
            (ppu-vram-address ppu) (ppu-temporary-address ppu)
            (ppu-write-toggle ppu) nil)))

(defun %request-nmi! (ppu &optional (delay 3))
  (unless (ppu-nmi-pending-p ppu)
    (setf (ppu-nmi-delay-p ppu) delay))
  (setf (ppu-nmi-pending-p ppu) t)
  ppu)

(defun %nmi-delay-active-p (ppu)
  (let ((delay (ppu-nmi-delay-p ppu)))
    (and (numberp delay) (plusp delay))))

(defun %nmi-suppression-window-p (ppu)
  (and (= (ppu-scanline ppu) 241)
       (<= (ppu-dot ppu) 2)))

(defun %cancel-nmi-delay! (ppu)
  (when (%nmi-delay-active-p ppu)
    (setf (ppu-nmi-delay-p ppu) nil
          (ppu-nmi-pending-p ppu) nil))
  ppu)

(defun %ppu-write-control-register! (ppu value &optional cpu-access-p)
  (let ((was-enabled (logbitp 7 (ppu-control ppu))))
    (setf (ppu-control ppu) value
          (ppu-temporary-address ppu)
          (logior (logand (ppu-temporary-address ppu) #xF3FF)
                  (ash (logand value 3) 10)))
    (when (and (not was-enabled)
               (logbitp 7 value)
               (logbitp 7 (ppu-status ppu)))
      (%request-nmi! ppu (if (and cpu-access-p
                                   (= (ppu-scanline ppu) 241))
                              6
                              3)))
    (when (and was-enabled (not (logbitp 7 value)))
      (%cancel-nmi-delay! ppu))))

(defun %ppu-write-mask-register! (ppu value)
  (setf (ppu-mask ppu) value
        (ppu-rendering-mask-pending ppu) value
        (ppu-rendering-mask-delay ppu) 2
        (ppu-rendering-mask-valid-p ppu) t))

(defun %ppu-write-oam-data-register! (ppu value)
  (setf (aref (ppu-oam ppu) (ppu-oam-address ppu)) value
        (ppu-oam-address ppu) (mod (1+ (ppu-oam-address ppu)) 256)))

(defun %ppu-write-address-register! (ppu value)
  (%write-address! ppu value)
  (unless (ppu-write-toggle ppu)
    (%ppu-address-bus! ppu (ppu-vram-address ppu))))

(defun %ppu-write-data-register! (ppu value)
  (ppu-write-vram! ppu (ppu-vram-address ppu) value t)
  (%ppu-vram-increment ppu)
  (%ppu-address-bus! ppu (ppu-vram-address ppu)))

(defun ppu-write-register! (ppu register value &optional cpu-access-p)
  (setf value (logand value #xFF))
  (%ppu-drive-decay! ppu value)
  (case (logand register 7)
    (0 (%ppu-write-control-register! ppu value cpu-access-p))
    (1 (%ppu-write-mask-register! ppu value))
    (3 (setf (ppu-oam-address ppu) value))
    (4 (%ppu-write-oam-data-register! ppu value))
    (5 (%write-scroll! ppu value))
    (6 (%ppu-write-address-register! ppu value))
    (7 (%ppu-write-data-register! ppu value)))
  value)
