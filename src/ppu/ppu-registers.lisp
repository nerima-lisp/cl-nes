(in-package #:cl-nes)
(defun %ppu-oam2-reset! (ppu)
  (setf (ppu-oam2-address ppu) 0
        (ppu-oam2-increment-suppressed-p ppu) nil)
  ppu)
(defun %ppu-oam2-increment! (ppu)
  (unless (ppu-oam2-increment-suppressed-p ppu)
    (if (= (ppu-oam2-address ppu) #x1F)
        (setf (ppu-oam2-address ppu) 0
              (ppu-oam2-increment-suppressed-p ppu) t)
        (incf (ppu-oam2-address ppu))))
  (ppu-oam2-address ppu))
(defun %ppu-oam2-write! (ppu value)
  (setf (aref (ppu-secondary-oam ppu) (ppu-oam2-address ppu)) value
        (ppu-secondary-oam-data-latch ppu) value
        (ppu-sprite-evaluation-secondary-oam-write-p ppu) t)
  (%ppu-oam2-increment! ppu)
  value)
(defun %ppu-oam2-read-data (ppu)
  (if (and (< (ppu-secondary-oam-count ppu) 8)
           (= (ppu-oam2-address ppu)
              (* 4 (ppu-secondary-oam-count ppu))))
      ;; The first empty fetch slot reads OAM[63].Y before its $FF bytes.
      (aref (ppu-oam ppu) #xFC)
      (aref (ppu-secondary-oam ppu) (ppu-oam2-address ppu))))

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
  (let* ((oam-address (ppu-primary-oam-bus-address ppu))
         (dot (ppu-dot ppu))
         (rendering-p
           (and (or (< (ppu-scanline ppu) +ppu-height+)
                    (= (ppu-scanline ppu) 261))
                (let ((mask (%ppu-effective-mask ppu)))
                  (or (logbitp 3 mask) (logbitp 4 mask)))))
         (phase-p (and bus-access-p rendering-p))
         (secondary-count (ppu-secondary-oam-count ppu))
         (first-empty-sprite-p
           (and (< secondary-count 8)
                (or (plusp secondary-count)
                    (= (aref (ppu-secondary-oam ppu) 0) #xFF))))
         (first-empty-dot (+ 257 (* 8 secondary-count)))
         ;; CPU reads sample before the same cycle's PPU tick. Align the first
         ;; empty-slot fetch with the preceding register-read callback dot.
         (sprite-fetch-read-dot
           (if (and phase-p
                    first-empty-sprite-p
                    (<= (1- first-empty-dot) dot (+ first-empty-dot 6)))
               (1+ dot)
               dot))
         (clear-bus-p (and phase-p (<= 0 dot 64)))
         (evaluation-bus-p (and phase-p (<= 65 dot 256)))
         (sprite-fetch-p (and phase-p (<= 257 sprite-fetch-read-dot 320)))
         (secondary-bus-p
           (and phase-p (<= 321 dot 340)))
         (secondary-full-read-p
           (and evaluation-bus-p
                (not (ppu-sprite-evaluation-done-p ppu))
                (= secondary-count 8)
                (zerop (ppu-sprite-evaluation-m ppu))
                (evenp dot)))
         (raw
           (cond
             (clear-bus-p #xFF)
             (sprite-fetch-p
              (let* ((offset (mod (- sprite-fetch-read-dot 257) 8))
                     (sprite (floor (- sprite-fetch-read-dot 257) 8))
                     (oam2-index (+ (* sprite 4) (min offset 3))))
                (cond
                  ((< sprite secondary-count)
                   (aref (ppu-secondary-oam ppu) oam2-index))
                  ((and first-empty-sprite-p
                        (= sprite secondary-count)
                        (zerop offset))
                   (aref (ppu-oam ppu) #xFC))
                  (first-empty-sprite-p #xFF)
                  (t (aref (ppu-secondary-oam ppu) oam2-index)))))
             ((or secondary-bus-p secondary-full-read-p)
              (aref (ppu-secondary-oam ppu) 0))
             (evaluation-bus-p
              ;; CPU reads precede this cycle's PPU ticks, so the latch
              ;; holds the primary OAM byte read on the preceding odd dot.
              (ppu-sprite-evaluation-latch ppu))
             (t (aref (ppu-oam ppu) oam-address))))
         (masked-p
           (and bus-access-p
                (not clear-bus-p)
                (not sprite-fetch-p)
                (not secondary-bus-p)
                (not secondary-full-read-p)
                (= (logand oam-address 3) 2)))
         (value (if masked-p (logand raw #xE3) raw)))
    (progn
      (%ppu-drive-decay! ppu value)
      (setf (ppu-primary-oam-bus-address ppu) oam-address)
      (when (or sprite-fetch-p secondary-bus-p secondary-full-read-p)
        (setf (ppu-secondary-oam-data-latch ppu) raw)))
    value))

(defun %ppu-read-data-register (ppu &optional bus-access-p)
  (let* ((address (ppu-vram-address ppu))
         (palette-p (>= (logand address #x3FFF) #x3F00))
         (mask (if (ppu-rendering-mask-valid-p ppu)
                   (ppu-rendering-mask ppu)
                   (ppu-mask ppu)))
         (rendering-p (and (or (< (ppu-scanline ppu) 240)
                               (= (ppu-scanline ppu) 261))
                           (or (logbitp 3 mask)
                               (logbitp 4 mask))))
         (value (if (and bus-access-p rendering-p (not palette-p))
                    nil
                    (ppu-read-vram ppu address nil (not bus-access-p))))
         (decay (%ppu-current-decay ppu))
         (result (if palette-p
                     (logior (logand value
                                     (if (logbitp 0 (ppu-mask ppu))
                                         #x30
                                         #x3F))
                             (logand decay #xC0))
                     (ppu-read-buffer ppu))))
    (%ppu-drive-decay! ppu result (if palette-p #x3F #xFF))
    (if (and bus-access-p rendering-p)
        (setf (ppu-read-buffer-pending-address ppu)
              (if palette-p (- address #x1000) address)
              ;; The rendering increment commits with the delayed read refill.
              (ppu-read-buffer-pending-delay ppu) 7
              (ppu-read-buffer-pending-p ppu) t)
        (progn
          (%ppu-vram-increment ppu)
          (setf (ppu-read-buffer ppu)
                (if palette-p
                    (ppu-read-vram ppu (- address #x1000) nil t)
                    value))))
    (unless (and bus-access-p rendering-p)
      (%ppu-address-bus! ppu (ppu-vram-address ppu)))
    result))

(defun ppu-read-register (ppu register &optional bus-access-p)
  (case (logand register 7)
    (2 (%ppu-read-status-register ppu bus-access-p))
    (4 (%ppu-read-oam-data-register ppu bus-access-p))
    (7 (%ppu-read-data-register ppu bus-access-p))
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
            (logior (logand (ppu-temporary-address ppu) #x7F00) value)
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
  (let ((phase (mod (ppu-dot ppu) 8)))
    ;; The mask rendering path has short and long settling windows within each fetch group.
    (setf (ppu-mask ppu) value
          (ppu-rendering-mask-pending ppu) value
          (ppu-rendering-mask-delay ppu) (if (<= 2 phase 6) 5 3)
          (ppu-rendering-mask-valid-p ppu) t)))

(defun %ppu-write-oam-data-register! (ppu value cpu-access-p)
  (if (and cpu-access-p (%ppu-rendering-scanline-p ppu))
      (setf (ppu-oam-address ppu)
            (mod (+ (ppu-oam-address ppu) 4) 256))
      (setf (aref (ppu-oam ppu) (ppu-oam-address ppu)) value
            (ppu-oam-address ppu)
            (mod (1+ (ppu-oam-address ppu)) 256)))
  (setf (ppu-primary-oam-bus-address ppu) (ppu-oam-address ppu)))

(defun %ppu-write-address-register! (ppu value cpu-access-p)
  (let ((second-write-p (ppu-write-toggle ppu)))
    (%write-address! ppu value)
    (when second-write-p
      (setf (ppu-pending-vram-address-copy-p ppu) t
            (ppu-pending-vram-address-copy-delay ppu) 2
            (ppu-pending-vram-address-copy-value ppu)
            (ppu-temporary-address ppu)
            (ppu-pending-vram-address-copy-wait-for-phase1-p ppu)
            (and cpu-access-p (%ppu-rendering-scanline-p ppu))
            (ppu-pending-vram-address-copy-phase1-seen-p ppu) nil))))

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
    (3 (setf (ppu-oam-address ppu) value
             (ppu-primary-oam-bus-address ppu) value
             (ppu-sprite-evaluation-address-latch ppu) value))
    (4 (%ppu-write-oam-data-register! ppu value cpu-access-p))
    (5 (%write-scroll! ppu value))
    (6 (%ppu-write-address-register! ppu value cpu-access-p))
    (7 (%ppu-write-data-register! ppu value)))
  value)
