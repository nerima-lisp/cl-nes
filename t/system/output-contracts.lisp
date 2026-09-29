(in-package #:cl-nes/test)

(defun output-test-pathname (type)
  (make-pathname :name (symbol-name (gensym "CL-NES-OUTPUT-"))
                 :type type
                 :defaults (uiop:temporary-directory)))

(defun read-output-octets (pathname)
  (with-open-file (stream pathname
                          :direction :input
                          :element-type '(unsigned-byte 8))
    (let ((octets (make-array (file-length stream)
                              :element-type '(unsigned-byte 8))))
      (read-sequence octets stream)
      octets)))

(describe "portable output API"
  (it "converts a framebuffer to RGB and writes PPM"
    (let* ((framebuffer
             (make-array +nes-framebuffer-size+
                         :element-type '(unsigned-byte 8)
                         :initial-element 1))
           (rgb (nes-framebuffer-rgb-octets framebuffer))
           (pathname (output-test-pathname "ppm")))
      (unwind-protect
           (progn
             (expect (length rgb)
                     :to-be (* +nes-framebuffer-size+ 3))
             (expect (aref rgb 0) :to-be 0)
             (expect (aref rgb 1) :to-be 0)
             (expect (aref rgb 2) :to-be 252)
             (nes-write-ppm pathname framebuffer)
             (let ((bytes (read-output-octets pathname)))
               (expect (length bytes)
                       :to-be (+ 15 (* +nes-framebuffer-size+ 3)))
               (expect (aref bytes 0) :to-be (char-code #\P))
               (expect (aref bytes 1) :to-be (char-code #\6))))
        (when (probe-file pathname)
          (delete-file pathname)))))
  (it "writes single-float 16-bit mono PCM WAV data"
    (let ((pathname (output-test-pathname "wav")))
      (unwind-protect
           (progn
             (nes-write-wav pathname #(-1.0f0 0.0f0 1.0f0) :sample-rate 22050)
             (let ((bytes (read-output-octets pathname)))
               (expect (length bytes) :to-be 50)
               (expect (aref bytes 0) :to-be (char-code #\R))
               (expect (aref bytes 1) :to-be (char-code #\I))
               (expect (aref bytes 8) :to-be (char-code #\W))
               (expect (aref bytes 12) :to-be (char-code #\f))
               (expect (aref bytes 36) :to-be (char-code #\d))
               (expect (aref bytes 34) :to-be 16)
               (expect (aref bytes 44) :to-be 1)
               (expect (aref bytes 45) :to-be 128)
               (expect (aref bytes 48) :to-be 255)
               (expect (aref bytes 49) :to-be 127)))
        (when (probe-file pathname)
          (delete-file pathname)))))
  (it "fills and reuses a fixed-size audio buffer while running frames"
    (let ((nes (make-nes :cartridge (make-fixture-cartridge)))
          (frames 0)
          (buffer (make-nes-audio-buffer :size 32))
          (callbacks 0)
          (same-buffer t))
      (expect (nes-run-frames/k
               nes 1
               (lambda (framebuffer)
                 (incf frames)
                 (expect (length framebuffer)
                         :to-be +nes-framebuffer-size+))
               :audio-buffer buffer
               :audio-continuation
               (lambda (received)
                 (incf callbacks)
                 (setf same-buffer (and same-buffer (eq received buffer)))
                 (expect (length (nes-audio-buffer-samples received)) :to-be 32)
                 (expect (nes-audio-buffer-count received) :to-be 32)))
              :to-be nes)
      (expect frames :to-be 1)
      (expect (plusp callbacks) :to-be t)
      (expect same-buffer :to-be t)))
  (it "suppresses a Nyquist input in the band-limited resampler"
    (let* ((buffer (make-nes-audio-buffer :size 32))
           (peak 0.0f0)
           (callbacks 0)
           (stream (cl-nes::%nes-make-audio-stream
                    44100 buffer
                    (lambda (received)
                      (incf callbacks)
                      (when (> callbacks 10)
                        (dotimes (index (nes-audio-buffer-count received))
                          (setf peak (max peak (abs (aref
                                                     (nes-audio-buffer-samples received)
                                                     index))))))))))
      (dotimes (cycle 10000)
        (cl-nes::%nes-audio-push! stream
                                  (if (evenp cycle) 1.0f0 0.0f0)))
      (expect (< peak 0.25f0) :to-be t)))
  (it "keeps the 30 kHz third harmonic below -60 dB at 48 kHz"
    (let* ((size 4096)
           (buffer (make-nes-audio-buffer :size size))
           (samples (make-array size :element-type 'single-float))
           (stream (cl-nes::%nes-make-audio-stream
                    48000 buffer
                    (lambda (received)
                      (replace samples (nes-audio-buffer-samples received)))))
           (magnitude
             (lambda (bin)
               (let ((real 0.0d0) (imaginary 0.0d0))
                 (dotimes (index size (sqrt (+ (* real real)
                                               (* imaginary imaginary))))
                   (let ((angle (* 2d0 pi bin index (/ 1d0 size))))
                     (incf real (* (aref samples index) (cos angle)))
                     (decf imaginary (* (aref samples index) (sin angle))))))))
           (fundamental (funcall magnitude 853))
           (aliased-third (funcall magnitude 1536)))
      (dotimes (cycle 170000)
        (cl-nes::%nes-audio-push!
         stream
         (if (< (mod (* cycle 10000) +nes-ntsc-cpu-frequency+)
                (/ +nes-ntsc-cpu-frequency+ 2))
             1.0f0
             0.0f0)))
      (setf fundamental (funcall magnitude 853)
            aliased-third (funcall magnitude 1536))
      (expect (< (* 20.0d0 (log (max 1.0d-12
                                       (/ aliased-third fundamental))
                                10.0d0))
                  -60.0d0)
              :to-be t)))
  (it "forwards input-continuation to each frame's execution"
    (let* ((controller-1 (make-controller))
           (nes (make-nes :cartridge (make-fixture-cartridge)
                          :controller-1 controller-1))
           (input-calls 0))
      (expect (nes-run-frames/k
               nes 3
               (lambda (framebuffer) (declare (ignore framebuffer)) nil)
               :input-continuation
               (lambda (current)
                 (incf input-calls)
                 (controller-set-buttons! controller-1 +button-a+)
                 (expect current :to-be nes)))
              :to-be nes)
      (expect input-calls :to-be 3)
      (expect (controller-buttons controller-1) :to-be +button-a+))))
