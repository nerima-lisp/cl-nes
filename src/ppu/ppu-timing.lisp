(in-package #:cl-nes)

(defun %start-vblank! (ppu)
  (if (ppu-vblank-suppression-p ppu)
      (setf (ppu-vblank-suppression-p ppu) nil)
      (progn
        (setf (ppu-status ppu) (logior (ppu-status ppu) #x80)
              (ppu-frame-ready-p ppu) t)
        (when (logbitp 7 (ppu-control ppu))
          (%request-nmi! ppu)))))

(defun %start-frame! (ppu)
  (setf (ppu-status ppu) (logand (ppu-status ppu) #x1F)
        (ppu-frame-ready-p ppu) nil
        (ppu-nmi-pending-p ppu) nil
        (ppu-nmi-delay-p ppu) nil))

(defun %ppu-effective-mask (ppu)
  (if (ppu-rendering-mask-valid-p ppu)
      (ppu-rendering-mask ppu)
      (ppu-mask ppu)))

(defun %ppu-advance-rendering-mask! (ppu)
  (when (ppu-rendering-mask-valid-p ppu)
    (when (plusp (ppu-rendering-mask-delay ppu))
      (decf (ppu-rendering-mask-delay ppu)))
    (when (zerop (ppu-rendering-mask-delay ppu))
      (setf (ppu-rendering-mask ppu)
            (ppu-rendering-mask-pending ppu)))))

(defun %ppu-rendering-scanline-p (ppu)
  (and (or (< (ppu-scanline ppu) 240)
           (= (ppu-scanline ppu) 261))
       (let ((mask (%ppu-effective-mask ppu)))
         (or (logbitp 3 mask)
             (logbitp 4 mask)))))

(defun %ppu-odd-frame-skip-enabled-p (ppu)
  (let ((mask (%ppu-effective-mask ppu)))
    (or (logbitp 3 mask)
        (logbitp 4 mask))))
(defun %ppu-horizontal-increment! (ppu)
  (if (= (logand (ppu-vram-address ppu) #x1F) #x1F)
      (setf (ppu-vram-address ppu)
            (logxor (ppu-vram-address ppu) #x041F))
      (incf (ppu-vram-address ppu)))
  (setf (ppu-vram-address ppu) (logand (ppu-vram-address ppu) #x7FFF)))

(defun %ppu-vertical-increment! (ppu)
  (if (< (logand (ppu-vram-address ppu) #x7000) #x7000)
      (incf (ppu-vram-address ppu) #x1000)
      (let ((coarse-y (logand (ash (ppu-vram-address ppu) -5) #x1F)))
        (setf (ppu-vram-address ppu)
              (logand (ppu-vram-address ppu) #x0FFF))
        (cond
          ((= coarse-y 29)
           (setf (ppu-vram-address ppu)
                 (logxor (logand (ppu-vram-address ppu)
                                 (lognot #x03E0))
                         #x0800)))
          ((= coarse-y 31)
           (setf (ppu-vram-address ppu)
                 (logand (ppu-vram-address ppu) (lognot #x03E0))))
          (t
           (incf (ppu-vram-address ppu) #x0020)))))
  (setf (ppu-vram-address ppu) (logand (ppu-vram-address ppu) #x7FFF)))

(defun %ppu-copy-horizontal! (ppu)
  (setf (ppu-vram-address ppu)
        (logior (logand (ppu-vram-address ppu) #x7BE0)
                (logand (ppu-temporary-address ppu) #x041F))))

(defun %ppu-copy-vertical! (ppu)
  (setf (ppu-vram-address ppu)
        (logior (logand (ppu-vram-address ppu) #x041F)
                (logand (ppu-temporary-address ppu) #x7BE0))))

(progn
  (defun %ppu-latch-background-address! (ppu address fetch-phase)
    (%ppu-address-bus! ppu address)
    (setf (ppu-background-fetch-address ppu) address
          (ppu-background-fetch-phase ppu) fetch-phase
          (ppu-address-latch-low ppu)
          (if (and (ppu-read-buffer-pending-p ppu)
                   (= (ppu-read-buffer-pending-delay ppu) 1))
              (ppu-last-background-read-value ppu)
              (logand address #xFF))))

  (defun %ppu-background-read-address (ppu fetch-phase)
    (if (= (ppu-background-fetch-phase ppu) fetch-phase)
        (logior (logand (ppu-background-fetch-address ppu) #x3F00)
                (ppu-address-latch-low ppu))
        (ppu-address-bus ppu)))

  (defun %ppu-read-background-pattern! (ppu dot fetch-phase high-plane-p)
    (multiple-value-bind (split-p split-x split-y)
        (%ppu-mmc5-split-state ppu dot)
      (declare (ignore split-x split-y))
      (let* ((v (ppu-vram-address ppu))
             (exram (and (not split-p)
                         (%ppu-mmc5-exram-tile
                          ppu (logand v #x1F)
                          (logand (ash v -5) #x1F))))
             (address (%ppu-background-read-address ppu fetch-phase)))
        (%ppu-address-bus! ppu address)
        (let ((value (%ppu-mmc5-background-chr
                      ppu address split-p exram)))
          (if high-plane-p
              (setf (ppu-next-pattern-high ppu) value)
              (setf (ppu-next-pattern-low ppu) value))
          (setf (ppu-last-background-read-value ppu) value
                (ppu-background-fetch-phase ppu) 0)
          value)))))

(defun %ppu-background-fetch! (ppu dot)
  (let ((phase (logand dot 7)))
    (case phase
      ((1)
       (multiple-value-bind (split-p split-x split-y)
           (%ppu-mmc5-split-state ppu dot)
         (declare (ignore split-x split-y))
         (let ((address (+ #x2000 (logand (ppu-vram-address ppu) #x0FFF))))
           (if split-p
               (setf (ppu-background-fetch-phase ppu) 0)
               (%ppu-latch-background-address! ppu address phase)))))
      ((2)
       (multiple-value-bind (split-p split-x split-y)
           (%ppu-mmc5-split-state ppu dot)
         (let ((value (if split-p
                          (%ppu-mmc5-exram-byte ppu split-x (floor split-y 8))
                          (ppu-read-vram ppu (%ppu-background-read-address ppu 1)))))
           (setf (ppu-next-tile ppu) value)
           (unless split-p
             (setf (ppu-last-background-read-value ppu) value
                   (ppu-background-fetch-phase ppu) 0))
           (values value t))))
      ((3)
       (let* ((v (ppu-vram-address ppu))
              (tile-x (logand v #x1F))
              (tile-y (logand (ash v -5) #x1F)))
         (multiple-value-bind (split-p split-x split-y)
             (%ppu-mmc5-split-state ppu dot)
           (let* ((effective-x (if split-p split-x tile-x))
                  (effective-y (if split-p (floor split-y 8) tile-y))
                  (exram (and (not split-p)
                              (%ppu-mmc5-exram-tile ppu tile-x tile-y)))
                  (address (if split-p
                               (+ #x2000 #x3C0
                                  (* (floor effective-y 4) 8)
                                  (floor effective-x 4))
                               (+ #x23C0 (logand v #x0C00)
                                  (ash (logand v #x0380) -4)
                                  (ash (logand v #x001F) -2)))))
             (if exram
                 (setf (ppu-background-fetch-phase ppu) 0)
                 (%ppu-latch-background-address! ppu address phase))))))
      ((4)
       (let* ((v (ppu-vram-address ppu))
              (tile-x (logand v #x1F))
              (tile-y (logand (ash v -5) #x1F)))
         (multiple-value-bind (split-p split-x split-y)
             (%ppu-mmc5-split-state ppu dot)
           (let* ((effective-x (if split-p split-x tile-x))
                  (effective-y (if split-p (floor split-y 8) tile-y))
                  (exram (and (not split-p)
                              (%ppu-mmc5-exram-tile ppu tile-x tile-y)))
                  (value (or exram
                             (ppu-read-vram ppu (%ppu-background-read-address ppu 3))))
                  (quadrant (%ppu-attribute-quadrant effective-x effective-y)))
             (setf (ppu-next-attribute ppu)
                   (if exram
                       (ldb (byte 2 6) exram)
                       (ldb (byte 2 (* quadrant 2)) value))
                   (ppu-background-fetch-phase ppu) 0)
             (unless exram
               (setf (ppu-last-background-read-value ppu) value))
             (values value t)))))
      ((5)
       (multiple-value-bind (split-p split-x split-y)
           (%ppu-mmc5-split-state ppu dot)
         (declare (ignore split-x))
         (let ((address (+ (if (and (not split-p)
                                    (logbitp 4 (ppu-control ppu)))
                               #x1000
                               0)
                           (* (ppu-next-tile ppu) 16)
                           (if split-p
                               (logand split-y 7)
                               (logand (ash (ppu-vram-address ppu) -12) 7)))))
           (%ppu-latch-background-address! ppu address phase))))
      ((6)
       (let ((value (%ppu-read-background-pattern! ppu dot 5 nil)))
         (values value t)))
      ((7)
       (multiple-value-bind (split-p split-x split-y)
           (%ppu-mmc5-split-state ppu dot)
         (declare (ignore split-x))
         (let ((address (+ (if (and (not split-p)
                                    (logbitp 4 (ppu-control ppu)))
                               #x1000
                               0)
                           (* (ppu-next-tile ppu) 16)
                           (if split-p
                               (logand split-y 7)
                               (logand (ash (ppu-vram-address ppu) -12) 7))
                           8)))
           (%ppu-latch-background-address! ppu address phase))))
      ((0)
       (let ((value (%ppu-read-background-pattern! ppu dot 7 t)))
         (setf (ppu-background-shift-low ppu)
               (logand #xFFFF
                       (logior (logand #xFF00 (ppu-background-shift-low ppu))
                               (ldb (byte 8 0) (ppu-next-pattern-low ppu))))
               (ppu-background-shift-high ppu)
               (logand #xFFFF
                       (logior (logand #xFF00 (ppu-background-shift-high ppu))
                               (ldb (byte 8 0) (ppu-next-pattern-high ppu))))
               (ppu-attribute-shift-low ppu)
               (logand #xFFFF
                       (logior (logand #xFF00 (ppu-attribute-shift-low ppu))
                               (if (logbitp 0 (ppu-next-attribute ppu))
                                   #xFF
                                   0)))
               (ppu-attribute-shift-high ppu)
               (logand #xFFFF
                       (logior (logand #xFF00 (ppu-attribute-shift-high ppu))
                               (if (logbitp 1 (ppu-next-attribute ppu))
                                   #xFF
                                   0))))
         (%ppu-horizontal-increment! ppu)
         (values value t))))))

(defun %ppu-sprite-fetch! (ppu dot v-before-dot)
  (let* ((sprite (floor (- dot 257) 8))
         (offset (mod (- dot 257) 8))
         (base (* sprite 4))
         (frozen-p (ppu-oam2-increment-suppressed-p ppu))
         (oam2-data (when frozen-p (%ppu-oam2-read-data ppu)))
         (y (if frozen-p
                oam2-data
                (aref (ppu-secondary-oam ppu) base)))
         (tile (if frozen-p
                   oam2-data
                   (aref (ppu-secondary-oam ppu) (+ base 1))))
         (attributes (if frozen-p
                         oam2-data
                         (aref (ppu-secondary-oam ppu) (+ base 2))))
         (height (if (logbitp 5 (ppu-control ppu)) 16 8))
         (row (mod
               (- (if (= (ppu-scanline ppu) 261)
                      0
                      (1+ (ppu-scanline ppu)))
                  (1+ y))
               height))
         ;; Empty sprite slots still fetch pattern data from their dummy tile.
         (address
           (%sprite-pattern-address ppu tile attributes row)))
    (case offset
      ((0 2)
       ;; Sprite fetches first put an address on the bus, then read it one dot later.
       ;; The first garbage fetch mixes v from before and after the horizontal reload.
       (%ppu-address-bus!
        ppu
        (if (= dot 257)
            (logior #x2000
                    (logand (ppu-vram-address ppu) #x0F00)
                    (logand v-before-dot #x00FF))
            (+ #x2000 (logand (ppu-vram-address ppu) #x0FFF)))))
      ((1 3)
       (values (ppu-read-vram ppu (ppu-address-bus ppu)) t))
      ((4)
       (%ppu-address-bus! ppu address))
      ((5)
       (let ((value (ppu-read-vram ppu (ppu-address-bus ppu) t)))
         (when (< sprite (ppu-secondary-oam-count ppu))
           (setf (aref (ppu-sprite-shift-low ppu) sprite) value))
         (values value t)))
      ((6)
       (%ppu-address-bus! ppu (+ address 8)))
      ((7)
       (let ((value (ppu-read-vram ppu (ppu-address-bus ppu) t)))
         (when (< sprite (ppu-secondary-oam-count ppu))
           (let ((attributes
                  (if frozen-p
                      oam2-data
                      (aref (ppu-secondary-oam ppu) (+ (* sprite 4) 2))))
                 (x
                  (if frozen-p
                      oam2-data
                      (aref (ppu-secondary-oam ppu) (+ (* sprite 4) 3)))))
             (setf (aref (ppu-sprite-shift-high ppu) sprite) value
                   (aref (ppu-sprite-x-counter ppu) sprite) x
                   (aref (ppu-sprite-counter-counting ppu) sprite) nil
                   (aref (ppu-sprite-attributes ppu) sprite) attributes)
             (when (logbitp 6 attributes)
               (setf (aref (ppu-sprite-shift-low ppu) sprite) (%reverse-byte
                                                               (aref (ppu-sprite-shift-low ppu) sprite))
                     (aref (ppu-sprite-shift-high ppu) sprite) (%reverse-byte
                                                                (aref (ppu-sprite-shift-high ppu) sprite))))))
         (values value t))))))

(defun %ppu-clock-pipeline!
    (ppu &optional (pipeline-scanline-p nil pipeline-scanline-p-supplied-p))
  (let ((pipeline-scanline-p (if pipeline-scanline-p-supplied-p
                                 pipeline-scanline-p
                               (or (< (ppu-scanline ppu) 240)
                                   (= (ppu-scanline ppu) 261))))
        (scanline (ppu-scanline ppu))
        (dot (ppu-dot ppu))
        (v-before-dot (ppu-vram-address ppu))
        (fetch-data-p nil)
        (fetch-data nil))
    (when pipeline-scanline-p
      (when (or (<= 1 dot 256) (<= 321 dot 336))
        (multiple-value-bind (value data-p)
            (%ppu-background-fetch! ppu dot)
          (when data-p
            (setf fetch-data-p t
                  fetch-data value))))
      ;; The delayed sprite-fetch signal adds an increment as it falls on dot 321.
      (when (= dot 321)
        (%ppu-oam2-increment! ppu))
      (when (or (= dot 63) (= dot 255) (= dot 339))
        (%ppu-oam2-reset! ppu))
      (when (= dot 339)
        (fill (ppu-sprite-counter-counting ppu) t))
      (when (or (= dot 337) (= dot 339))
        (%ppu-address-bus!
         ppu (+ #x2000 (logand (ppu-vram-address ppu) #x0FFF))))
      (when (or (= dot 338) (= dot 340))
        (setf fetch-data (ppu-read-vram ppu (ppu-address-bus ppu))
              fetch-data-p t))
      (when (= dot 256)
        (%ppu-vertical-increment! ppu))
      (when (= dot 257)
        (%ppu-copy-horizontal! ppu))
      (when (<= 257 dot 320)
        (progn
          ;; The half-dot-delayed OAM2 gate is represented by this pipeline dot label.
          (when (not (logbitp 2 dot))
            (%ppu-oam2-increment! ppu))
          (setf (ppu-oam-address ppu) 0)
          (multiple-value-bind (value data-p)
              (%ppu-sprite-fetch! ppu dot v-before-dot)
            (when data-p
              (setf fetch-data-p t
                    fetch-data value))))
        (when (= dot 320)
          (setf (ppu-sprite-render-count ppu)
                (ppu-secondary-oam-count ppu)
                (ppu-sprite-evaluation-index ppu) 1)
          (dotimes (sprite (ppu-sprite-render-count ppu))
            (setf (aref (ppu-sprite-indexes ppu) sprite)
                  (aref (ppu-sprite-evaluated-indexes ppu) sprite)))))
      (when (and (= scanline 261) (<= 280 dot 304))
        (%ppu-copy-vertical! ppu))
      (progn
        (when (and pipeline-scanline-p
                   (= dot 341)
                   (or (< scanline 239)
                       (= scanline 261))
                   (not (and (= scanline 261)
                             (ppu-odd-frame-p ppu)
                             (%ppu-odd-frame-skip-enabled-p ppu))))
          (let* ((v (ppu-vram-address ppu))
                 (address (+ (if (logbitp 4 (ppu-control ppu))
                                 #x1000
                               0)
                             (* (ppu-next-tile ppu) 16)
                             (logand (ash v -12) 7))))
            (%ppu-address-bus! ppu address)))
        (when (and (or (< scanline 240) (= scanline 261))
                   (<= 65 dot 256))
          (%ppu-evaluate-sprites!
           ppu
           (if (= scanline 261) 0 (1+ scanline))
           dot))
        (when (= dot 65) (setf (ppu-sprite-evaluation-active-p ppu) t))))
    (when (= dot 1) (setf (ppu-sprite-evaluation-active-p ppu) nil))
    (when (and (= dot 320)
               (ppu-sprite-evaluation-active-p ppu)
               (or (< scanline 240) (= scanline 261)))
      (setf (ppu-sprite-render-count ppu)
            (ppu-secondary-oam-count ppu)
            (ppu-sprite-evaluation-index ppu) 1)
      (dotimes (sprite (ppu-sprite-render-count ppu))
        (setf (aref (ppu-sprite-indexes ppu) sprite)
              (aref (ppu-sprite-evaluated-indexes ppu) sprite))))
    (values fetch-data-p fetch-data)))
(defun %ppu-rendering-address-latch-p (scanline dot)
  (and (or (< scanline 240) (= scanline 261))
       (or (and (or (<= 1 dot 256)
                    (<= 321 dot 336))
                (member (logand dot 7) '(1 3 5 7)))
           (and (<= 257 dot 320)
                (member (mod (- dot 257) 8) '(0 2 4 6)))
           (member dot '(337 339)))))
(progn
  (defvar *ppu-rendering-data-p* nil)
  (defvar *ppu-rendering-data* nil)
  (defun %ppu-clock-read-buffer! (ppu scanline rendering-scanline-p)
    (when (ppu-read-buffer-pending-p ppu)
      (decf (ppu-read-buffer-pending-delay ppu))
      (cond
       ((= (ppu-read-buffer-pending-delay ppu) 2)
        (unless (and rendering-scanline-p
                     (%ppu-rendering-address-latch-p
                      scanline (ppu-dot ppu)))
          (%ppu-address-bus! ppu (ppu-read-buffer-pending-address ppu))
          (setf (ppu-address-latch-low ppu)
                (logand (ppu-read-buffer-pending-address ppu) #xFF))))
       ((zerop (ppu-read-buffer-pending-delay ppu))
        (let* ((phase (logand (ppu-dot ppu) 7))
               (background-overlap-p
                (and rendering-scanline-p
                     (= (ppu-background-fetch-phase ppu) phase)
                     (%ppu-rendering-address-latch-p scanline (ppu-dot ppu))))
               (address
                (if background-overlap-p
                    (logior
                     (logand (ppu-background-fetch-address ppu) #x3F00)
                     (ppu-address-latch-low ppu))
                  (ppu-read-buffer-pending-address ppu)))
               (value (if *ppu-rendering-data-p*
                          *ppu-rendering-data*
                        (ppu-read-vram ppu address nil t))))
          (setf (ppu-read-buffer ppu) value
                (ppu-read-buffer-pending-p ppu) nil
                (ppu-last-background-read-value ppu) value)
          (%ppu-horizontal-increment! ppu)
          (%ppu-vertical-increment! ppu)))))))

(defun ppu-tick! (ppu &optional (ticks 1))
  (declare (type ppu ppu) (type fixnum ticks)
           (optimize (speed 3) (safety 1) (debug 1)))
  (loop repeat ticks
        with odd-frame-skip-p = nil
        do
        (progn
          (setf (aref (ppu-status-history ppu) 1)
                (aref (ppu-status-history ppu) 0)
                (aref (ppu-status-history ppu) 0)
                (ppu-status ppu))
          (setf odd-frame-skip-p (and (= (ppu-scanline ppu) 261)
                                      (= (ppu-dot ppu) 338)
                                      (ppu-odd-frame-p ppu)
                                      (%ppu-odd-frame-skip-enabled-p ppu))))
        (when (and (numberp (ppu-nmi-delay-p ppu))
                   (plusp (ppu-nmi-delay-p ppu)))
          (decf (ppu-nmi-delay-p ppu)))
        (%ppu-clock-decay! ppu 1)
        (%ppu-advance-rendering-mask! ppu)
        (let* ((scanline (ppu-scanline ppu))
               (rendering-scanline-p (%ppu-rendering-scanline-p ppu)))
          (incf (ppu-dot ppu))
          (when (and (< scanline +ppu-height+)
                     (<= 1 (ppu-dot ppu) 256))
            (%ppu-render-visible-dot! ppu))
          (when (and (or (< scanline +ppu-height+) (= scanline 261))
                     (<= 1 (ppu-dot ppu) 256))
            (%ppu-shift-sprite-registers!
             ppu (%ppu-rendering-enabled-p ppu)))
          (when (and rendering-scanline-p
                     (or (<= 1 (ppu-dot ppu) 256)
                         (<= 321 (ppu-dot ppu) 336)))
            (%ppu-shift-background-registers! ppu))
          (multiple-value-bind (rendering-data-p rendering-data)
              (%ppu-clock-pipeline! ppu rendering-scanline-p)
            (let ((*ppu-rendering-data-p* rendering-data-p)
                  (*ppu-rendering-data* rendering-data))
              (%ppu-clock-read-buffer! ppu scanline rendering-scanline-p))))
        (when (and (= (ppu-scanline ppu) 241) (= (ppu-dot ppu) 1))
          (%start-vblank! ppu))
        (when (and (= (ppu-scanline ppu) 261) (= (ppu-dot ppu) 1))
          (%start-frame! ppu))
        (when (and (= (ppu-scanline ppu) 261)
                   (= (ppu-dot ppu) 339)
                   (ppu-odd-frame-p ppu)
                   odd-frame-skip-p)
          (setf (ppu-dot ppu) 340))
        (when (>= (ppu-dot ppu) 341)
          (setf (ppu-dot ppu) 0)
          (incf (ppu-scanline ppu))
          (when (>= (ppu-scanline ppu) 262)
            (setf (ppu-scanline ppu) 0
                  (ppu-odd-frame-p ppu) (not (ppu-odd-frame-p ppu))))
          (cartridge-clock-scanline! (ppu-cartridge ppu)
                                     (ppu-scanline ppu))))
  ppu)

(defun ppu-take-nmi! (ppu)
  (when (ppu-nmi-pending-p ppu)
    (if (%nmi-delay-active-p ppu)
        nil
        (progn
          (setf (ppu-nmi-pending-p ppu) nil)
          t))))
