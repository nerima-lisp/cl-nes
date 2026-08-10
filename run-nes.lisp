(in-package #:cl-user)

(defparameter *run-nes-root*
  (make-pathname :name nil
                 :type nil
                 :defaults (or *load-truename*
                                *load-pathname*
                                *default-pathname-defaults*)))

(require :asdf)
(load (merge-pathnames "cl-nes.asd" *run-nes-root*))
(asdf:load-system "cl-nes")

(defconstant +frame-width+ 256)
(defconstant +frame-height+ 240)

;; Common 64-entry NES palette, stored as consecutive RGB octets.
(defparameter *nes-palette*
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

(defun print-usage ()
  (format *error-output*
          "Usage: sbcl --script run-nes.lisp ROM.nes [frames] [output-prefix]~%"
          ))

(defun exit-with-error (code control &rest arguments)
  (format *error-output* "Error: ")
  (apply #'format *error-output* control arguments)
  (terpri *error-output*)
  (when (= code 2)
    (print-usage))
  (sb-ext:exit :code code))

(defun positive-integer-or-nil (text)
  (handler-case
      (let ((value (parse-integer text :junk-allowed nil)))
        (and (plusp value) value))
    (error () nil)))

(defun parse-command-line ()
  (let ((arguments (rest sb-ext:*posix-argv*)))
    (unless (<= 1 (length arguments) 3)
      (exit-with-error 2 "expected ROM.nes and at most two optional arguments"))
    (let ((rom (first arguments))
          (frames-text (second arguments))
          (prefix (third arguments)))
      (when (zerop (length rom))
        (exit-with-error 2 "ROM path must not be empty"))
      (let ((frames (if frames-text
                        (positive-integer-or-nil frames-text)
                        1)))
        (unless frames
          (exit-with-error 2 "frames must be a positive integer"))
        (when (and prefix (zerop (length prefix)))
          (exit-with-error 2 "output-prefix must not be empty"))
        (values rom frames (or prefix "frame"))))))

(defun write-ascii-octets (text stream)
  (loop for character across text
        do (write-byte (char-code character) stream)))

(defun framebuffer-rgb-octets (framebuffer)
  (let ((expected-size (* +frame-width+ +frame-height+)))
    (unless (= (length framebuffer) expected-size)
      (error "Unexpected framebuffer size: ~D (expected ~D)"
             (length framebuffer) expected-size))
    (let ((rgb (make-array (* expected-size 3)
                           :element-type '(unsigned-byte 8))))
      (loop for palette-index across framebuffer
            for rgb-index from 0 by 3
            for palette-offset = (* (logand palette-index #x3F) 3)
            do (setf (aref rgb rgb-index)
                     (aref *nes-palette* palette-offset)
                     (aref rgb (1+ rgb-index))
                     (aref *nes-palette* (+ palette-offset 1))
                     (aref rgb (+ rgb-index 2))
                     (aref *nes-palette* (+ palette-offset 2))))
      rgb)))

(defun frame-pathname (prefix frame-number)
  (format nil "~A-~4,'0D.ppm" prefix frame-number))

(defun write-ppm (pathname framebuffer)
  (with-open-file (stream pathname
                          :direction :output
                          :if-exists :supersede
                          :if-does-not-exist :create
                          :element-type '(unsigned-byte 8))
    (write-ascii-octets
     (format nil "P6~%~D ~D~%255~%" +frame-width+ +frame-height+)
     stream)
    (write-sequence (framebuffer-rgb-octets framebuffer) stream)))

(defun run-rom (rom frames prefix)
  (let ((cartridge
          (handler-case
              (cl-nes:load-cartridge rom)
            (cl-nes:nes-error (condition)
              (exit-with-error 1 "ROM error: ~A" condition))
            (file-error (condition)
              (exit-with-error 1 "ROM error: ~A" condition)))))
    (let ((nes (cl-nes:make-nes :cartridge cartridge)))
      (handler-case
          (loop for frame-number from 1 to frames
                do (write-ppm (frame-pathname prefix frame-number)
                              (cl-nes:nes-run-frame/k nes #'identity)))
        (cl-nes:nes-error (condition)
          (exit-with-error 1 "Execution error: ~A" condition))
        (file-error (condition)
          (exit-with-error 1 "Output error: ~A" condition))))))

(multiple-value-call #'run-rom (parse-command-line))
