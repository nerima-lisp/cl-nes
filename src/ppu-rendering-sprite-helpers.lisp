(in-package #:cl-nes)

(defun %ppu-sprite-height (ppu)
  (if (logbitp 5 (ppu-control ppu)) 16 8))

(defun %sprite-visible-p (ppu x local-x local-y height)
  (and (<= 0 local-x) (< local-x 8)
       (<= 0 local-y) (< local-y height)
       (or (>= x 8) (logbitp 4 (ppu-mask ppu)))))

(defun %sprite-pixel-coordinates (attributes local-x local-y height)
  (values
   (if (logbitp 6 attributes) (- 7 local-x) local-x)
   (if (logbitp 7 attributes)
       (- (1- height) local-y)
       local-y)))

(defun %sprite-pattern-location (ppu tile pixel-y height)
  (if (= height 16)
      (values
       (if (logbitp 0 tile) #x1000 0)
       (+ (logand tile #xFE) (floor pixel-y 8))
       (mod pixel-y 8))
      (values
       (if (logbitp 3 (ppu-control ppu)) #x1000 0)
       tile
       pixel-y)))

(defun %sprite-pattern-color (ppu pattern-base tile-number row pixel-x)
  (let* ((bit (- 7 pixel-x))
         (pattern-address (+ pattern-base (* tile-number 16) row))
         (low (ppu-read-vram ppu pattern-address t))
         (high (ppu-read-vram ppu (+ pattern-address 8) t)))
    (logior (ldb (byte 1 bit) low)
            (ash (ldb (byte 1 bit) high) 1))))

(defun %sprite-palette-color (ppu attributes color)
  (logand
   (ppu-read-vram ppu (+ #x3F10 (* (logand attributes 3) 4) color))
   #x3F))

(defun %sprite-bounds (ppu sprite)
  (let* ((base (* sprite 4))
         (top (1+ (aref (ppu-oam ppu) base)))
         (left (aref (ppu-oam ppu) (+ base 3)))
         (height (%ppu-sprite-height ppu)))
    (values (max 0 top)
            (min +ppu-height+ (+ top height))
            (max 0 left)
            (min +ppu-width+ (+ left 8)))))
