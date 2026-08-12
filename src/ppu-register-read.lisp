(in-package #:cl-nes)

(defun %ppu-read-open-bus (ppu bus-access-p)
  (if bus-access-p
      (%ppu-current-decay ppu)
      0))

(defun %ppu-read-status (ppu bus-access-p)
  (let* ((decay (%ppu-current-decay ppu))
         (value (if bus-access-p
                    (logior (logand (ppu-status ppu) #xE0)
                            (logand decay #x1F))
                    (ppu-status ppu))))
    (%ppu-read-decay-result (ppu value #xE0)
      (prog1 value
        (setf (ppu-status ppu) (logand (ppu-status ppu) #x7F)
              (ppu-write-toggle ppu) nil)
        (%cancel-nmi-delay! ppu)))))

(defun %ppu-read-oam-data (ppu bus-access-p)
  (let* ((raw (aref (ppu-oam ppu) (ppu-oam-address ppu)))
         (value (if (and bus-access-p
                         (= (logand (ppu-oam-address ppu) 3) 2))
                    (logand raw #xE3)
                    raw)))
    (%ppu-read-decay-result (ppu value)
      value)))

(defun %ppu-read-data (ppu)
  (let* ((address (ppu-vram-address ppu))
         (palette-p (>= (logand address #x3FFF) #x3F00))
         (value (ppu-read-vram ppu address))
         (decay (%ppu-current-decay ppu))
         (result (if palette-p
                     (logior (logand value #x3F)
                             (logand decay #xC0))
                     (ppu-read-buffer ppu))))
    (%ppu-read-decay-result (ppu result (if palette-p #x3F #xFF))
      (prog1 result
        (setf (ppu-read-buffer ppu)
              (if palette-p
                  (ppu-read-vram ppu (- address #x1000))
                  value))
        (%ppu-vram-increment ppu)
        (%ppu-clock-address-a12! ppu)))))

(defun ppu-read-register (ppu register &optional bus-access-p)
  (%ppu-read-register-dispatch register))
