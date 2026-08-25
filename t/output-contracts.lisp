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
  (it "writes unsigned 8-bit mono PCM WAV data"
    (let ((pathname (output-test-pathname "wav")))
      (unwind-protect
           (progn
             (nes-write-wav pathname #(0 128 255) :sample-rate 22050)
             (let ((bytes (read-output-octets pathname)))
               (expect (length bytes) :to-be 47)
               (expect (aref bytes 0) :to-be (char-code #\R))
               (expect (aref bytes 1) :to-be (char-code #\I))
               (expect (aref bytes 8) :to-be (char-code #\W))
               (expect (aref bytes 12) :to-be (char-code #\f))
               (expect (aref bytes 36) :to-be (char-code #\d))
               (expect (aref bytes 44) :to-be 0)
               (expect (aref bytes 45) :to-be 128)
               (expect (aref bytes 46) :to-be 255)))
        (when (probe-file pathname)
          (delete-file pathname)))))
  (it "samples audio while running complete frames"
    (let ((nes (make-nes :cartridge (make-fixture-cartridge)))
          (frames 0)
          (samples (make-array 0
                               :element-type '(unsigned-byte 8)
                               :adjustable t
                               :fill-pointer 0)))
      (expect (nes-run-frames/k
               nes 1
               (lambda (framebuffer)
                 (incf frames)
                 (expect (length framebuffer)
                         :to-be +nes-framebuffer-size+))
               :sample-continuation
               (lambda (sample)
                 (vector-push-extend sample samples)))
              :to-be nes)
      (expect frames :to-be 1)
      (expect (plusp (length samples)) :to-be t)
      (expect (every (lambda (sample) (<= 0 sample 255)) samples)
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
