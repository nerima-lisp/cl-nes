(in-package #:cl-nes)

(defun %start-vblank! (ppu)
  (setf (ppu-status ppu) (logior (ppu-status ppu) #x80)
        (ppu-frame-ready-p ppu) t)
  (%render-sprites! ppu (%render-background! ppu))
  (when (logbitp 7 (ppu-control ppu))
    (%request-nmi! ppu)))

(defun %start-frame! (ppu)
  (setf (ppu-status ppu) (logand (ppu-status ppu) #x1F)
        (ppu-frame-ready-p ppu) nil))

(defun %ppu-rendering-scanline-p (ppu)
  (and (or (< (ppu-scanline ppu) 240)
           (= (ppu-scanline ppu) 261))
       (or (logbitp 3 (ppu-mask ppu))
           (logbitp 4 (ppu-mask ppu)))))

(defun %ppu-clock-render-a12! (ppu high-p &optional (low-cycles 1))
  (when (and (ppu-cartridge ppu)
             (%ppu-rendering-scanline-p ppu))
    (cartridge-clock-ppu-a12! (ppu-cartridge ppu) high-p low-cycles)))

(defun %ppu-a12-high-p (ppu)
  "Return the coarse PPU address phase used by MMC3's A12 edge detector.

  The renderer does not model every nametable fetch, but it preserves the
  pattern-fetch phases that matter to MMC3's low-time filter.  A pattern-table
  access occupies four PPU dots in each eight-dot fetch group.  Background
  fetches also occur at dots 321-336 for the next scanline, while sprite
  fetches occupy dots 257-320." 
  (let ((dot (ppu-dot ppu)))
    (or (and (logbitp 4 (ppu-control ppu))
             (or (and (<= 10 dot 256)
                      (< (mod (- dot 10) 8) 4))
                 (and (<= 330 dot 336)
                      (< (mod (- dot 330) 8) 4))))
        (and (logbitp 3 (ppu-control ppu))
             (<= 266 dot 320)
             (< (mod (- dot 266) 8) 4)))))

(defun ppu-tick! (ppu &optional (ticks 1))
  (loop repeat ticks do
    (incf (ppu-dot ppu))
    (when (%ppu-rendering-scanline-p ppu)
      (%ppu-clock-render-a12! ppu (%ppu-a12-high-p ppu)))
    (when (and (= (ppu-scanline ppu) 241) (= (ppu-dot ppu) 1))
      (%start-vblank! ppu))
    (when (and (= (ppu-scanline ppu) 261) (= (ppu-dot ppu) 1))
      (%start-frame! ppu))
    (when (and (= (ppu-scanline ppu) 261)
               (= (ppu-dot ppu) 339)
               (ppu-odd-frame-p ppu)
               (%ppu-rendering-scanline-p ppu))
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
    (if (ppu-nmi-delay-p ppu)
        (progn
          (setf (ppu-nmi-delay-p ppu) nil)
          nil)
        (progn
          (setf (ppu-nmi-pending-p ppu) nil)
          t))))

