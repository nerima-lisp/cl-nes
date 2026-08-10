(in-package #:cl-user)

(defparameter *run-rom-suite-root*
  (make-pathname :name nil
                 :type nil
                 :defaults (or *load-truename*
                                *load-pathname*
                                *default-pathname-defaults*)))

(require :asdf)
(load (merge-pathnames "cl-nes.asd" *run-rom-suite-root*))
(asdf:load-system "cl-nes")

(defconstant +default-max-steps+ 1000000)
(defconstant +output-start+ #x6000)
(defconstant +output-size+ #x100)
(defconstant +poll-interval+ 1024)

(defun usage-error (control &rest arguments)
  (apply #'format *error-output* control arguments)
  (format *error-output* "~%Usage: sbcl --script run-rom-suite.lisp ROM.nes [max-steps] [mmc3|mmc6|mmc3-alt]~%")
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
    (unless (<= 1 (length arguments) 3)
      (usage-error "expected ROM.nes, max-steps, and an optional MMC3 variant"))
    (let ((rom (first arguments))
          (steps-text (second arguments))
          (variant-text (third arguments)))
      (when (zerop (length rom))
        (usage-error "ROM path must not be empty"))
      (let ((max-steps (if steps-text
                          (positive-integer-or-nil steps-text)
                          +default-max-steps+)))
        (unless max-steps
          (usage-error "max-steps must be a positive integer"))
        (let ((variant (if variant-text
                          (mapper4-variant-or-nil variant-text)
                          :mmc3)))
          (unless variant
            (usage-error "MMC3 variant must be mmc3, mmc6, or mmc3-alt"))
          (values rom max-steps variant))))))

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

(defun output-memory-text (bus)
  (let ((text (make-string +output-size+)))
    (loop for offset from 0 below +output-size+
          for value = (cl-nes:bus-read bus (+ +output-start+ offset))
          do (setf (char text offset)
                   (if (<= 32 value 126)
                       (code-char value)
                       #\.)))
    (string-trim '(#\Space #\.) text)))

(defun result-marker (text)
  (let ((upper (string-upcase text)))
    (cond
      ((or (search "FAILED" upper)
           (search "FAIL" upper))
       "fail")
      ((or (search "PASSED" upper)
           (search "PASS" upper))
       "pass")
      (t nil))))

(defun framebuffer-checksum (nes)
  (let ((checksum 0))
    (loop for value across (cl-nes:ppu-framebuffer (cl-nes:nes-ppu nes))
          do (setf checksum
                   (logand #xFFFFFFFF
                           (+ (* checksum 33) value))))
    (format nil "~8,'0X" checksum)))

(defun emit-result (rom status mapper steps frames pc seconds checksum output error)
  ;; TSV keeps batch output machine-readable while preserving the human-readable ROM text.
  (format t "~A~C~A~C~D~C~D~C~A~C~,3F~C~A~C~A~C~A~C~A~%"
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
          (printable-field output)
          #\Tab
          (printable-field error)
          #\Tab
          (printable-field rom))
  (finish-output))

(defun run-rom (rom max-steps &optional (mapper4-variant :mmc3))
  (let ((started-at (get-internal-real-time))
        (status "error")
        (mapper nil)
        (steps 0)
        (frames 0)
        (pc nil)
        (checksum nil)
        (output "")
        (error-text "")
        (nes nil))
    (handler-case
        (let ((cartridge (cl-nes:load-cartridge
                          rom :mapper4-variant mapper4-variant)))
          (setf mapper (cl-nes:cartridge-mapper cartridge)
                nes (cl-nes:make-nes :cartridge cartridge))
          (loop while (and (< steps max-steps)
                           (null (result-marker output)))
                do (incf steps)
                   (cl-nes:nes-step/k nes #'identity)
                   (let ((frame-completed-p
                           (cl-nes:ppu-frame-ready-p (cl-nes:nes-ppu nes))))
                     (when frame-completed-p
                       (incf frames)
                       (setf checksum (framebuffer-checksum nes)
                             (cl-nes:ppu-frame-ready-p (cl-nes:nes-ppu nes)) nil))
                     (when (or (zerop (mod steps +poll-interval+))
                               frame-completed-p)
                       (setf output (output-memory-text (cl-nes:nes-bus nes))))))
          (setf status (or (result-marker output)
                           (if (= steps max-steps) "limit" "no-result"))))
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
      (setf pc (format nil "~4,'0X" (cl-nes:cpu-pc (cl-nes:nes-cpu nes))))
      (unless (result-marker output)
        (setf output (output-memory-text (cl-nes:nes-bus nes)))))
    (emit-result rom status mapper steps frames pc
                 (/ (- (get-internal-real-time) started-at)
                    internal-time-units-per-second)
                 checksum output error-text)
    status))

(let ((status (multiple-value-call #'run-rom (parse-command-line))))
  (unless (string= status "pass")
    (sb-ext:exit :code 1)))
