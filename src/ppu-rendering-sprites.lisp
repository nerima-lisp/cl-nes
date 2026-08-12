(in-package #:cl-nes)

(defun %sprite-pixel (ppu sprite-index x y)
  (let* ((oam (ppu-oam ppu))
         (base (* sprite-index 4))
         (sprite-y (1+ (aref oam base)))
         (tile (aref oam (+ base 1)))
         (attributes (aref oam (+ base 2)))
         (sprite-x (aref oam (+ base 3)))
         (height (%ppu-sprite-height ppu))
         (local-x (- x sprite-x))
         (local-y (- y sprite-y)))
    (when (%sprite-visible-p ppu x local-x local-y height)
      (multiple-value-bind (pixel-x pixel-y)
          (%sprite-pixel-coordinates attributes local-x local-y height)
        (multiple-value-bind (pattern-base tile-number row)
            (%sprite-pattern-location ppu tile pixel-y height)
          (let ((color (%sprite-pattern-color ppu pattern-base tile-number row
                                              pixel-x)))
          (unless (zerop color)
            (values
             (%sprite-palette-color ppu attributes color)
             t
             (logbitp 5 attributes)))))))))

(defun %sprite-count-on-scanline (ppu y)
  (let ((height (%ppu-sprite-height ppu)))
    (loop for sprite below 64
          count (let ((top (1+ (aref (ppu-oam ppu) (* sprite 4)))))
                  (and (<= top y) (< y (+ top height)))))))

(defun %draw-sprite-pixel! (ppu sprite x y background-opaque occupied)
  (multiple-value-bind (color present behind-background)
      (%sprite-pixel ppu sprite x y)
    (when present
      (with-ppu-frame-index (index x y)
        (unless (plusp (aref occupied index))
          (when (and (zerop sprite)
                     (< x 255)
                     (plusp (aref background-opaque index)))
            (setf (ppu-status ppu)
                  (logior (ppu-status ppu) #x40)))
          (setf (aref occupied index) 1)
          (unless (and behind-background
                       (plusp (aref background-opaque index)))
            (setf (aref (ppu-framebuffer ppu) index) color)))))))

(defun %render-sprites! (ppu background-opaque)
  (when (logbitp 3 (ppu-mask ppu))
    (let ((occupied (make-array (* +ppu-width+ +ppu-height+)
                                :element-type 'bit
                                :initial-element 0)))
      (loop for y below +ppu-height+
            when (> (%sprite-count-on-scanline ppu y) 8)
              do (setf (ppu-status ppu) (logior (ppu-status ppu) #x20))
                 (return))
      (loop for sprite below 64 do
        (multiple-value-bind (start-y end-y start-x end-x)
            (%sprite-bounds ppu sprite)
          (loop for y from start-y below end-y do
            (loop for x from start-x below end-x do
              (%draw-sprite-pixel! ppu sprite x y background-opaque occupied))))))))
