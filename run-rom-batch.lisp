(in-package #:cl-user)

(defparameter *run-rom-batch-root*
  (make-pathname :name nil
                 :type nil
                 :defaults (or *load-truename*
                                *load-pathname*
                                *default-pathname-defaults*)))

(defconstant +default-max-steps+ 1000000)
(defconstant +default-target-frames+ 1)

(defun usage-error (control &rest arguments)
  (apply #'format *error-output* control arguments)
  (format *error-output*
          "~%Usage: sbcl --script run-rom-batch.lisp MANIFEST [max-steps] [frames] [mmc3|mmc6|mmc3-alt]~%")
  (sb-ext:exit :code 2))

(defun positive-integer-or-nil (text)
  (handler-case
      (let ((value (parse-integer text :junk-allowed nil)))
        (and (plusp value) value))
    (error () nil)))

(defun mapper4-variant-or-nil (text)
  (let ((normalized (string-downcase text)))
    (cond
      ((string= normalized "mmc3") :mmc3)
      ((string= normalized "mmc6") :mmc6)
      ((string= normalized "mmc3-alt") :mmc3-alt)
      (t nil))))

(defun parse-command-line ()
  (let ((arguments (rest sb-ext:*posix-argv*)))
    (unless (<= 1 (length arguments) 4)
      (usage-error "expected a manifest, max-steps, frames, and an optional MMC3 variant"))
    (let ((manifest (first arguments))
          (steps-text (second arguments))
          (frames-text (third arguments))
          (variant-text (fourth arguments)))
      (when (zerop (length manifest))
        (usage-error "manifest path must not be empty"))
      (let ((max-steps (if steps-text
                          (positive-integer-or-nil steps-text)
                          +default-max-steps+))
            (target-frames (if frames-text
                               (positive-integer-or-nil frames-text)
                               +default-target-frames+)))
        (unless max-steps
          (usage-error "max-steps must be a positive integer"))
        (unless target-frames
          (usage-error "frames must be a positive integer"))
        (let ((variant (if variant-text
                          (mapper4-variant-or-nil variant-text)
                          :mmc3)))
          (unless variant
            (usage-error "MMC3 variant must be mmc3, mmc6, or mmc3-alt"))
          (values manifest max-steps target-frames variant))))))

(defun manifest-line (line)
  (string-trim '(#\Space #\Tab #\Return #\Newline) line))

(defun read-rom-manifest (manifest)
  (with-open-file (stream manifest :direction :input)
    (loop for line = (read-line stream nil nil)
          while line
          for entry = (manifest-line line)
          unless (or (zerop (length entry))
                     (char= (char entry 0) #\#))
            collect entry)))

(defparameter *run-rom-batch-config*
  (multiple-value-bind (manifest max-steps target-frames mapper4-variant)
      (parse-command-line)
    (handler-case
        (let ((roms (read-rom-manifest manifest)))
          (unless roms
            (usage-error "manifest contains no ROM paths: ~A" manifest))
          (list roms max-steps target-frames mapper4-variant))
      (file-error (condition)
        (usage-error "cannot read manifest ~A: ~A" manifest condition)))))

(require :asdf)
(load (merge-pathnames "cl-nes.asd" *run-rom-batch-root*))
(asdf:load-system "cl-nes")

(defun printable-field (value)
  (let ((text (princ-to-string (or value ""))))
    (with-output-to-string (stream)
      (loop for character across text
            for code = (char-code character)
            do (cond
                 ((or (= code 9) (= code 10) (= code 13))
                  (write-char #\Space stream))
                 ((<= 32 code 126)
                  (write-char character stream))
                 (t
                  (write-char #\. stream)))))))

(defun framebuffer-checksum (nes)
  (let ((checksum 0))
    (loop for value across (cl-nes:ppu-framebuffer (cl-nes:nes-ppu nes))
          do (setf checksum
                   (logand #xFFFFFFFF
                           (+ (* checksum 33) value))))
    (format nil "~8,'0X" checksum)))

(defun emit-header ()
  (format t "status~Cmapper~Csteps~Cframes~Cpc~Cseconds~Cchecksum~Cerror~Crom~%"
          #\Tab #\Tab #\Tab #\Tab #\Tab #\Tab #\Tab #\Tab)
  (finish-output))

(defun emit-result (rom status mapper steps frames pc seconds checksum error)
  (format t "~A~C~A~C~D~C~D~C~A~C~,3F~C~A~C~A~C~A~%"
          (printable-field status)
          #\Tab
          (printable-field mapper)
          #\Tab
          steps
          #\Tab
          frames
          #\Tab
          (printable-field pc)
          #\Tab
          seconds
          #\Tab
          (printable-field checksum)
          #\Tab
          (printable-field error)
          #\Tab
          (printable-field rom))
  (finish-output))

(defun run-rom (rom max-steps target-frames &optional (mapper4-variant :mmc3))
  (let ((started-at (get-internal-real-time))
        (status "error")
        (mapper nil)
        (steps 0)
        (frames 0)
        (pc nil)
        (checksum nil)
        (error-text "")
        (nes nil))
    (handler-case
        (let ((cartridge (cl-nes:load-cartridge
                          rom :mapper4-variant mapper4-variant)))
          (setf mapper (cl-nes:cartridge-mapper cartridge)
                nes (cl-nes:make-nes :cartridge cartridge))
          (loop while (and (< steps max-steps)
                           (< frames target-frames)
                           (not (cl-nes:cpu-stopped-p (cl-nes:nes-cpu nes))))
                do (incf steps)
                   (cl-nes:nes-step/k nes #'identity)
                   (when (cl-nes:ppu-frame-ready-p (cl-nes:nes-ppu nes))
                     (incf frames)
                     (setf checksum (framebuffer-checksum nes)
                           (cl-nes:ppu-frame-ready-p (cl-nes:nes-ppu nes)) nil)))
          (setf status
                (cond
                  ((>= frames target-frames) "frame")
                  ((cl-nes:cpu-stopped-p (cl-nes:nes-cpu nes)) "stopped")
                  (t "limit"))))
      (cl-nes:unsupported-mapper (condition)
        (setf status "unsupported"
              mapper (cl-nes:unsupported-mapper-number condition)
              error-text condition))
      (cl-nes:invalid-rom (condition)
        (setf status "invalid"
              error-text condition))
      (cl-nes:nes-error (condition)
        (setf status "error"
              error-text condition))
      (file-error (condition)
        (setf status "error"
              error-text condition))
      (error (condition)
        (setf status "error"
              error-text condition)))
    (when nes
      (setf pc (format nil "~4,'0X" (cl-nes:cpu-pc (cl-nes:nes-cpu nes)))))
    (emit-result rom status mapper steps frames pc
                 (/ (- (get-internal-real-time) started-at)
                    internal-time-units-per-second)
                 checksum error-text)
    status))

(destructuring-bind (roms max-steps target-frames mapper4-variant)
    *run-rom-batch-config*
  (emit-header)
  (let ((statuses
          (mapcar (lambda (rom)
                    (run-rom rom max-steps target-frames mapper4-variant))
                  roms)))
    (unless (every (lambda (status) (string= status "frame")) statuses)
      (sb-ext:exit :code 1))))
