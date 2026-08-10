(in-package #:cl-nes)

(defun ppu-reset! (ppu)
  "Reset the PPU's register, timing, and presentation state.

VRAM, palette RAM, and OAM are retained, matching the useful part of a
console reset for callers that want to preserve cartridge-backed state."
  (setf (ppu-control ppu) 0
        (ppu-mask ppu) 0
        (ppu-status ppu) 0
        (ppu-oam-address ppu) 0
        (ppu-vram-address ppu) 0
        (ppu-temporary-address ppu) 0
        (ppu-fine-x ppu) 0
        (ppu-write-toggle ppu) nil
        (ppu-scroll-x ppu) 0
        (ppu-scroll-y ppu) 0
        (ppu-read-buffer ppu) 0
        (ppu-scanline ppu) 0
        (ppu-dot ppu) 0
        (ppu-frame-ready-p ppu) nil
        (ppu-odd-frame-p ppu) nil
        (ppu-nmi-pending-p ppu) nil
        (ppu-nmi-delay-p ppu) nil
        (ppu-decay-value ppu) 0
        (ppu-decay-clock ppu) 0
        (ppu-decay-next-expiry ppu) most-positive-fixnum)
  (fill (ppu-decay-deadlines ppu) 0)
  (fill (ppu-framebuffer ppu) 0)
  ppu)

(defun ppu-load-cartridge! (ppu cartridge)
  (setf (ppu-cartridge ppu) cartridge)
  (when (and cartridge (cartridge-four-screen-p cartridge))
    (unless (= (length (ppu-nametable ppu)) #x1000)
      (setf (ppu-nametable ppu)
            (make-array #x1000 :element-type '(unsigned-byte 8)
                        :initial-element 0))))
  (when (and cartridge (not (cartridge-four-screen-p cartridge)))
    (unless (= (length (ppu-nametable ppu)) #x800)
      (setf (ppu-nametable ppu)
            (make-array #x800 :element-type '(unsigned-byte 8)
                        :initial-element 0))))
  (ppu-reset! ppu)
  ppu)

(defun make-ppu (&optional cartridge)
  (let ((ppu (%make-ppu)))
    (ppu-load-cartridge! ppu cartridge)
    ppu))

(defun %ppu-address (address)
  (mod address +ppu-vram-size+))

(defun %palette-index (address)
  (let ((index (mod (- address #x3F00) #x20)))
    (if (member index '(#x10 #x14 #x18 #x1C))
        (- index #x10)
        index)))

(defun %nametable-index (ppu address)
  (let* ((offset (mod (- address #x2000) #x1000))
         (table (floor offset #x400))
         (within (mod offset #x400))
         (mirrored-table
           (cond
             ((and (ppu-cartridge ppu)
                   (cartridge-four-screen-p (ppu-cartridge ppu)))
              table)
             ((and (ppu-cartridge ppu)
                   (eq (cartridge-mirroring (ppu-cartridge ppu))
                       :single-screen-upper))
              1)
             ((and (ppu-cartridge ppu)
                   (eq (cartridge-mirroring (ppu-cartridge ppu))
                       :single-screen-lower))
              0)
             ((and (ppu-cartridge ppu)
                   (eq (cartridge-mirroring (ppu-cartridge ppu)) :vertical))
              (mod table 2))
             (t (floor table 2)))))
    (+ (* mirrored-table #x400) within)))

(defun %ppu-mmc5-p (ppu)
  (and (ppu-cartridge ppu)
       (= (cartridge-mapper (ppu-cartridge ppu)) 5)))

(defun %ppu-nametable-address (address)
  (if (>= address #x3000)
      (- address #x1000)
      address))

(defun %ppu-read-nametable (ppu address)
  (let ((address (%ppu-nametable-address address)))
    (if (not (%ppu-mmc5-p ppu))
        (aref (ppu-nametable ppu) (%nametable-index ppu address))
        (multiple-value-bind (source within)
            (cartridge-mmc5-nametable-location
             (ppu-cartridge ppu) address)
          (case source
            (:ciram-0 (aref (ppu-nametable ppu) within))
            (:ciram-1 (aref (ppu-nametable ppu) (+ #x400 within)))
            (:exram (aref (cartridge-mapper5-exram
                           (ppu-cartridge ppu))
                          within))
            (:fill (cartridge-mmc5-fill-value
                    (ppu-cartridge ppu) within)))))))

(defun %ppu-write-nametable! (ppu address value)
  (let ((address (%ppu-nametable-address address)))
    (if (not (%ppu-mmc5-p ppu))
        (setf (aref (ppu-nametable ppu) (%nametable-index ppu address))
              value)
        (multiple-value-bind (source within)
            (cartridge-mmc5-nametable-location
             (ppu-cartridge ppu) address)
          (case source
            (:ciram-0 (setf (aref (ppu-nametable ppu) within) value))
            (:ciram-1 (setf (aref (ppu-nametable ppu) (+ #x400 within))
                            value))
            (:exram (setf (aref (cartridge-mapper5-exram
                                 (ppu-cartridge ppu))
                                within)
                          value))
            (:fill nil))))
    value))

(defun ppu-read-vram (ppu address &optional (sprite-p nil))
  (let ((address (%ppu-address address)))
    (cond
      ((< address #x2000)
       (if (ppu-cartridge ppu)
           (or (cartridge-read-chr (ppu-cartridge ppu) address sprite-p) 0)
           0))
      ((< address #x3F00)
       (%ppu-read-nametable ppu address))
      (t
       (aref (ppu-palette ppu) (%palette-index address))))))

(defun ppu-write-vram! (ppu address value)
  (let ((address (%ppu-address address))
        (value (logand value #xFF)))
    (cond
      ((< address #x2000)
       (when (ppu-cartridge ppu)
         (cartridge-write-chr! (ppu-cartridge ppu) address value)))
      ((< address #x3F00)
       (%ppu-write-nametable! ppu address value))
      (t
       (setf (aref (ppu-palette ppu) (%palette-index address)) value)))
    value))

(defun %ppu-vram-increment (ppu)
  (incf (ppu-vram-address ppu) (if (logbitp 2 (ppu-control ppu)) 32 1))
  (setf (ppu-vram-address ppu) (%ppu-address (ppu-vram-address ppu)))
  (ppu-vram-address ppu))

(defun %ppu-address-a12-high-p (address)
  (logbitp 12 (logand address #x3FFF)))

(defun %ppu-clock-address-a12! (ppu)
  "Expose explicit PPU address-bus changes to MMC3's A12 detector.

The renderer supplies the normal fetch phase, but CPU-visible $2006/$2007
accesses also change the PPU address bus.  Those accesses are used by the
MMC3 test ROMs to exercise the edge detector while rendering is disabled."
  (when (ppu-cartridge ppu)
    ;; A CPU register access leaves the line low for the full MMC3 filter
    ;; window before a subsequent high address is observed.
    (cartridge-clock-ppu-a12! (ppu-cartridge ppu)
                               (%ppu-address-a12-high-p
                                (ppu-vram-address ppu))
                               24)))

(defun ppu-read-register (ppu register)
  (case (logand register 7)
    (2
     (prog1 (ppu-status ppu)
       (setf (ppu-status ppu) (logand (ppu-status ppu) #x7F)
             (ppu-write-toggle ppu) nil)
       (%cancel-nmi-delay! ppu)))
    (4 (aref (ppu-oam ppu) (ppu-oam-address ppu)))
    (7
     (let* ((address (ppu-vram-address ppu))
            (value (ppu-read-vram ppu address)))
       (prog1 (if (< (logand address #x3FFF) #x3F00)
                  (ppu-read-buffer ppu)
                  value)
         (setf (ppu-read-buffer ppu)
               (if (>= (logand address #x3FFF) #x3F00)
                   (ppu-read-vram ppu (- address #x1000))
                   value))
         (%ppu-vram-increment ppu)
         (%ppu-clock-address-a12! ppu))))
    (otherwise 0)))

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

(defun %request-nmi! (ppu)
  (unless (ppu-nmi-pending-p ppu)
    (setf (ppu-nmi-delay-p ppu) t))
  (setf (ppu-nmi-pending-p ppu) t)
  ppu)

(defun %cancel-nmi-delay! (ppu)
  "Cancel an NMI whose edge has not reached the CPU yet.

The PPUSTATUS read and disabling NMI both lower the PPU's NMI output.  An
NMI already observed at a CPU boundary remains pending, but the short
propagation interval represented by NMI-DELAY-P can still be suppressed."
  (when (ppu-nmi-delay-p ppu)
    (setf (ppu-nmi-delay-p ppu) nil
          (ppu-nmi-pending-p ppu) nil))
  ppu)

(defun ppu-write-register! (ppu register value)
  (setf value (logand value #xFF))
  (case (logand register 7)
    (0
     (let ((was-enabled (logbitp 7 (ppu-control ppu))))
       (setf (ppu-control ppu) value
             (ppu-temporary-address ppu)
             (logior (logand (ppu-temporary-address ppu) #xF3FF)
                     (ash (logand value 3) 10)))
       (when (and (not was-enabled)
                  (logbitp 7 value)
                  (logbitp 7 (ppu-status ppu)))
         (%request-nmi! ppu))))
    (1 (setf (ppu-mask ppu) value))
    (3 (setf (ppu-oam-address ppu) value))
    (4
     (setf (aref (ppu-oam ppu) (ppu-oam-address ppu)) value
           (ppu-oam-address ppu) (mod (1+ (ppu-oam-address ppu)) 256)))
    (5 (%write-scroll! ppu value))
    (6
     (%write-address! ppu value)
     (unless (ppu-write-toggle ppu)
       (%ppu-clock-address-a12! ppu)))
    (7
     (ppu-write-vram! ppu (ppu-vram-address ppu) value)
     (%ppu-vram-increment ppu)
     (%ppu-clock-address-a12! ppu)))
  value)
