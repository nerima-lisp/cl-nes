(in-package #:cl-nes)

(defconstant +nes-frame-width+ 256)
(defconstant +nes-frame-height+ 240)
(defconstant +nes-framebuffer-size+
  (* +nes-frame-width+ +nes-frame-height+))
(defconstant +nes-ntsc-cpu-frequency+ 1789773)
(defconstant +nes-default-audio-sample-rate+ 44100)

(defparameter *nes-default-palette*
  #(124 124 124   0   0 252   0   0 188  68  40 188 148   0 132 168   0  32
    168  16   0 136  20   0  80  48   0   0 120   0   0 104   0   0  88   0
      0  64  88   0   0   0   0   0   0   0   0   0 188 188 188   0 120 248
      0  88 248 104  68 252 216   0 204 228   0  88 248  56   0 228  92  16
    172 124   0   0 184   0   0 168   0   0 168  68   0 136 136   0   0   0
      0   0   0   0   0   0 248 248 248  60 188 252 104 136 252 152 120 248
    248 120 248 248  88 152 248 120  88 252 160  68 248 184   0 184 248  24
     88 216  84  88 248 152   0 232 216 120 120 120   0   0   0   0   0   0
    252 252 252 164 228 252 184 184 248 216 184 248 248 184 248 248 164 192
    240 208 176 252 224 168 248 216 120 216 248 120 184 248 184 184 248 216
      0 252 252 248 216 248   0   0   0   0   0   0))

(defun %nes-check-positive-integer (value name)
  (unless (and (integerp value) (plusp value))
    (error "~A must be a positive integer: ~S" name value))
  value)

(defun %nes-check-framebuffer (framebuffer)
  (unless (= (length framebuffer) +nes-framebuffer-size+)
    (error "Unexpected framebuffer size: ~D (expected ~D)"
           (length framebuffer) +nes-framebuffer-size+))
  framebuffer)

(defun %nes-check-palette (palette)
  (unless (= (length palette) (* 64 3))
    (error "NES palette must contain 192 RGB octets: ~D" (length palette)))
  palette)

(defun nes-framebuffer-rgb-octets
    (framebuffer &key (palette *nes-default-palette*))
  "Convert a palette-index framebuffer to packed RGB octets.

PALETTE is a sequence of 192 RGB values for the 64 NES palette entries."
  (%nes-check-framebuffer framebuffer)
  (%nes-check-palette palette)
  (let ((rgb (make-array (* +nes-framebuffer-size+ 3)
                         :element-type '(unsigned-byte 8))))
    (loop for pixel below +nes-framebuffer-size+
          for rgb-index from 0 by 3
          for palette-offset = (* (logand (elt framebuffer pixel) #x3F) 3)
          do (setf (aref rgb rgb-index)
                   (elt palette palette-offset)
                   (aref rgb (1+ rgb-index))
                   (elt palette (+ palette-offset 1))
                   (aref rgb (+ rgb-index 2))
                   (elt palette (+ palette-offset 2))))
    rgb))

(defun %nes-write-ascii (text stream)
  (loop for character across text
        do (write-byte (char-code character) stream)))

(defun nes-write-ppm (pathname framebuffer &key (palette *nes-default-palette*))
  "Write FRAMEBUFFER as a binary P6 PPM image and return PATHNAME."
  (let ((rgb (nes-framebuffer-rgb-octets framebuffer :palette palette)))
    (with-open-file (stream pathname
                            :direction :output
                            :if-exists :supersede
                            :if-does-not-exist :create
                            :element-type '(unsigned-byte 8))
      (%nes-write-ascii
       (format nil "P6~%~D ~D~%255~%"
               +nes-frame-width+ +nes-frame-height+)
       stream)
      (write-sequence rgb stream)))
  pathname)

(defun %nes-sequence-to-octets (samples)
  (let ((octets (make-array (length samples)
                            :element-type '(unsigned-byte 8))))
    (loop for index below (length samples)
          for sample = (elt samples index)
          do (unless (and (integerp sample) (<= 0 sample 255))
               (error "Audio sample is not an unsigned 8-bit value: ~S"
                      sample))
             (setf (aref octets index) sample))
    octets))

(defun %nes-write-u16-le (value stream)
  (write-byte (ldb (byte 8 0) value) stream)
  (write-byte (ldb (byte 8 8) value) stream))

(defun %nes-write-u32-le (value stream)
  (dotimes (shift 4)
    (write-byte (ldb (byte 8 (* shift 8)) value) stream)))

(defun nes-write-wav
    (pathname samples &key (sample-rate +nes-default-audio-sample-rate+))
  "Write unsigned 8-bit mono PCM SAMPLES as a RIFF/WAVE file."
  (%nes-check-positive-integer sample-rate "Sample rate")
  (unless (<= sample-rate #xFFFFFFFF)
    (error "Sample rate does not fit in a WAV header: ~S" sample-rate))
  (let* ((octets (%nes-sequence-to-octets samples))
         (data-size (length octets)))
    (unless (<= data-size #xFFFFFFFF)
      (error "Audio data is too large for a RIFF/WAVE file: ~S" data-size))
    (with-open-file (stream pathname
                            :direction :output
                            :if-exists :supersede
                            :if-does-not-exist :create
                            :element-type '(unsigned-byte 8))
      (%nes-write-ascii "RIFF" stream)
      (%nes-write-u32-le (+ 36 data-size) stream)
      (%nes-write-ascii "WAVE" stream)
      (%nes-write-ascii "fmt " stream)
      (%nes-write-u32-le 16 stream)
      (%nes-write-u16-le 1 stream)
      (%nes-write-u16-le 1 stream)
      (%nes-write-u32-le sample-rate stream)
      (%nes-write-u32-le sample-rate stream)
      (%nes-write-u16-le 1 stream)
      (%nes-write-u16-le 8 stream)
      (%nes-write-ascii "data" stream)
      (%nes-write-u32-le data-size stream)
      (write-sequence octets stream)))
  pathname)

(defun nes-run-frames/k
    (nes frame-count frame-continuation
     &key (sample-rate +nes-default-audio-sample-rate+)
          sample-continuation)
  "Run FRAME-COUNT frames and call FRAME-CONTINUATION for each framebuffer.

When SAMPLE-CONTINUATION is supplied, it receives unsigned 8-bit mixer samples
at SAMPLE-RATE.  Sampling is driven by the same CPU-cycle clock as the PPU,
APU, DMA, and interrupt paths.  The function returns NES."
  (%nes-check-positive-integer frame-count "Frame count")
  (%nes-check-positive-integer sample-rate "Sample rate")
  (unless (functionp frame-continuation)
    (error "Frame continuation must be a function: ~S" frame-continuation))
  (when sample-continuation
    (unless (functionp sample-continuation)
      (error "Sample continuation must be a function: ~S"
             sample-continuation)))
  (let ((sample-phase 0))
    (labels ((sample-cycle ()
               (when sample-continuation
                 (incf sample-phase sample-rate)
                 (loop while (>= sample-phase +nes-ntsc-cpu-frequency+)
                       do (decf sample-phase +nes-ntsc-cpu-frequency+)
                          (funcall sample-continuation
                                   (apu-sample (nes-apu nes)))))))
      (dotimes (frame frame-count nes)
        (nes-run-frame/k nes frame-continuation
                         :cycle-hook #'sample-cycle)))))
