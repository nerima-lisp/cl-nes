(in-package #:cl-nes)

(defconstant +nes-frame-width+ 256)
(defconstant +nes-frame-height+ 240)
(defconstant +nes-framebuffer-size+ (* +nes-frame-width+ +nes-frame-height+))
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
  (%nes-check-framebuffer framebuffer)
  (%nes-check-palette palette)
  (let ((rgb (make-array (* +nes-framebuffer-size+ 3)
                         :element-type '(unsigned-byte 8))))
    (loop for pixel below +nes-framebuffer-size+
          for rgb-index from 0 by 3
          for palette-offset = (* (logand (elt framebuffer pixel) #x3F) 3)
          do (setf (aref rgb rgb-index) (elt palette palette-offset)
                   (aref rgb (1+ rgb-index)) (elt palette (+ palette-offset 1))
                   (aref rgb (+ rgb-index 2)) (elt palette (+ palette-offset 2))))
    rgb))

(defun %nes-write-ascii (text stream)
  (loop for character across text do (write-byte (char-code character) stream)))

(defun nes-write-ppm (pathname framebuffer &key (palette *nes-default-palette*))
  (let ((rgb (nes-framebuffer-rgb-octets framebuffer :palette palette)))
    (with-open-file (stream pathname :direction :output :if-exists :supersede
                            :if-does-not-exist :create
                            :element-type '(unsigned-byte 8))
      (%nes-write-ascii (format nil "P6~%~D ~D~%255~%"
                                +nes-frame-width+ +nes-frame-height+) stream)
      (write-sequence rgb stream)))
  pathname)

(defstruct (nes-audio-buffer (:constructor %make-nes-audio-buffer))
  (samples (make-array 0 :element-type 'single-float)
           :type (simple-array single-float (*)))
  (count 0 :type fixnum))

(defun make-nes-audio-buffer (&key (size 1024))
  (%nes-check-positive-integer size "Audio buffer size")
  (%make-nes-audio-buffer
   :samples (make-array size :element-type 'single-float :initial-element 0.0f0)))

(defstruct (nes-audio-stream (:constructor %make-nes-audio-stream))
  (sample-rate 44100 :type fixnum)
  (phase 0 :type fixnum)
  (ring (make-array 32768 :element-type 'single-float :initial-element 0.0f0)
        :type (simple-array single-float (*)))
  (ring-index 0 :type fixnum)
  (integrator 0.0f0 :type single-float)
  (last-mix 0.0f0 :type single-float)
  (seen-p nil)
  buffer
  continuation)

(defun %nes-make-audio-stream (sample-rate buffer continuation)
  (%make-nes-audio-stream :sample-rate sample-rate :buffer buffer
                           :continuation continuation))

(defun %nes-blip-add-step! (stream delta)
  (let* ((phase (floor (* 64 (nes-audio-stream-phase stream))
                       +nes-ntsc-cpu-frequency+))
         (ring (nes-audio-stream-ring stream))
         (base (nes-audio-stream-ring-index stream))
         (offset (* phase 256)))
    (dotimes (tap 256)
      (incf (aref ring (mod (+ base tap) (length ring)))
            (* delta (aref +nes-blip-kernel-table+ (+ offset tap)))))))

(defun %nes-audio-push! (stream sample)
  (let ((previous (nes-audio-stream-last-mix stream)))
    (unless (nes-audio-stream-seen-p stream)
      (setf (nes-audio-stream-seen-p stream) t))
    (unless (= sample previous)
      (%nes-blip-add-step! stream (- sample previous))
      (setf (nes-audio-stream-last-mix stream) sample)))
  (incf (nes-audio-stream-phase stream) (nes-audio-stream-sample-rate stream))
  (when (>= (nes-audio-stream-phase stream) +nes-ntsc-cpu-frequency+)
    (decf (nes-audio-stream-phase stream) +nes-ntsc-cpu-frequency+)
    (let* ((ring (nes-audio-stream-ring stream))
           (index (nes-audio-stream-ring-index stream))
           (value (aref ring index))
           (buffer (nes-audio-stream-buffer stream))
           (count (nes-audio-buffer-count buffer)))
      (incf (nes-audio-stream-integrator stream) value)
      (setf (aref ring index) 0.0f0
            (nes-audio-stream-ring-index stream) (mod (1+ index) (length ring))
            (aref (nes-audio-buffer-samples buffer) count)
            (- (* 2.0f0 (nes-audio-stream-integrator stream)) 1.0f0))
      (incf count)
      (setf (nes-audio-buffer-count buffer) count)
      (when (= count (length (nes-audio-buffer-samples buffer)))
        (funcall (nes-audio-stream-continuation stream) buffer)
        (setf (nes-audio-buffer-count buffer) 0)))))

(defun %nes-write-u16-le (value stream)
  (write-byte (ldb (byte 8 0) value) stream)
  (write-byte (ldb (byte 8 8) value) stream))

(defun %nes-write-u32-le (value stream)
  (dotimes (shift 4) (write-byte (ldb (byte 8 (* shift 8)) value) stream)))

(defun nes-write-wav
    (pathname samples &key (sample-rate +nes-default-audio-sample-rate+))
  (let* ((data-size (* 2 (length samples)))
         (pcm (make-array data-size :element-type '(unsigned-byte 8))))
    (with-open-file (stream pathname :direction :output :if-exists :supersede
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
      (%nes-write-u32-le (* sample-rate 2) stream)
      (%nes-write-u16-le 2 stream)
      (%nes-write-u16-le 16 stream)
      (%nes-write-ascii "data" stream)
      (%nes-write-u32-le data-size stream)
      (loop for sample across samples for index from 0 by 2
            for value = (round (* 32767.0 (max -1.0 (min 1.0 sample))))
            for encoded = (logand (+ value #x10000) #xFFFF)
            do (setf (aref pcm index) (ldb (byte 8 0) encoded)
                     (aref pcm (1+ index)) (ldb (byte 8 8) encoded)))
      (write-sequence pcm stream)))
  pathname)

(defun nes-run-frames/k
    (nes frame-count frame-continuation
     &key (sample-rate +nes-default-audio-sample-rate+)
          audio-buffer audio-continuation input-continuation)
  (%nes-check-positive-integer frame-count "Frame count")
  (%nes-check-positive-integer sample-rate "Sample rate")
  (unless (functionp frame-continuation)
    (error "Frame continuation must be a function: ~S" frame-continuation))
  (when (or audio-buffer audio-continuation)
    (unless (and audio-buffer audio-continuation)
      (error "AUDIO-BUFFER and AUDIO-CONTINUATION must be supplied together."))
    (unless (typep audio-buffer 'nes-audio-buffer)
      (error "Audio buffer must be made by MAKE-NES-AUDIO-BUFFER: ~S" audio-buffer))
    (unless (functionp audio-continuation)
      (error "Audio continuation must be a function: ~S" audio-continuation)))
  (when input-continuation
    (unless (functionp input-continuation)
      (error "Input continuation must be a function: ~S" input-continuation)))
  (let ((audio (and audio-buffer
                    (%nes-make-audio-stream sample-rate audio-buffer
                                            audio-continuation))))
    (labels ((sample-cycle ()
               (when audio (%nes-audio-push! audio (apu-mix (nes-apu nes))))))
      (dotimes (frame frame-count nes)
        (nes-run-frame/k nes frame-continuation :cycle-hook #'sample-cycle
                         :input-continuation input-continuation)))))
