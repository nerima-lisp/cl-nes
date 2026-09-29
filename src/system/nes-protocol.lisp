(in-package #:cl-nes)

(defun protocol-bus-range (bus start end)
  (loop for address from start to end collect (bus-read bus address)))

(defun protocol-ascii-result (bytes)
  (string-trim '(#\Space #\Tab #\Return #\Newline #\Null #\.)
               (coerce (mapcar (lambda (byte)
                                 (if (<= 32 byte 126)
                                     (code-char byte)
                                     #\.))
                               bytes)
                       'string)))

(defun protocol-framebuffer-hash (framebuffer)
  (let ((hash 2166136261))
    (loop for byte across framebuffer
          do (setf hash (logand #xffffffff
                                (* (logxor hash byte) 16777619))))
    (format nil "~8,'0X" hash)))

(defun protocol-run-frames-until (nes max-frames predicate &key input-continuation)
  (or (loop for frame from 1 to max-frames
            do (nes-run-frame/k nes #'identity
                                :input-continuation input-continuation)
               (when (funcall predicate frame)
                 (return frame)))
      max-frames))

(defun run-accuracy-coin-protocol (path max-frames)
  "Run AccuracyCoin and return its result RAM after pressing Start.

The ROM's automated mode is selected from its main menu with the NES Start
button.  The returned plist contains :RESULTS for $0400-$04FF and
:SHARED-DRAW for $03FF, plus the number of frames executed."
  (let* ((nes (make-nes :cartridge (load-cartridge path)))
         (bus (nes-bus nes))
         (frame-counter 0)
         (frames (protocol-run-frames-until
                  nes max-frames
                  (constantly nil)
                  :input-continuation
                  (lambda (current-nes)
                    (incf frame-counter)
                    (controller-set-buttons!
                     (bus-controller-1 (nes-bus current-nes))
                     (if (<= frame-counter 180) +button-start+ 0))))))
    (list :frames frames
          :results (protocol-bus-range bus #x0400 #x04ff)
          :shared-draw (bus-read bus #x03ff))))

(defun run-blargg-protocol (path max-frames &key mapper4-variant)
  "Run PATH using the Blargg $6000 status/signature protocol.

The result is a plist with :PASSED, :FRAMES, :TEXT, :STATUS, :SIGNATURE, and
:HASH.  Both the CLI and the ROM-suite consume this function so the protocol
remains a single implementation."
  (let* ((load-args (if mapper4-variant
                        (list :mapper4-variant mapper4-variant)
                        nil))
         (nes (make-nes :cartridge (apply #'load-cartridge path load-args)))
         (last-text "")
         (frames nil))
    (setf frames
          (protocol-run-frames-until
           nes max-frames
           (lambda (frame)
             (declare (ignore frame))
             (let* ((bus (nes-bus nes))
                    (status (bus-read bus #x6000))
                    (signature-p (equal '(222 176 97)
                                        (protocol-bus-range bus #x6001 #x6003))))
               (setf last-text
                     (protocol-ascii-result
                      (protocol-bus-range bus #x6004 #x60ff)))
               (or (= status 1)
                   (and (zerop status) signature-p)
                   (and (/= status 0) (/= status #x80))
                   (search "FAILED" (string-upcase last-text)))))))
    (let* ((bus (nes-bus nes))
           (signature-ok (equal '(222 176 97)
                                (protocol-bus-range bus #x6001 #x6003)))
           (status (bus-read bus #x6000)))
      (list :passed (and signature-ok (zerop status))
            :frames frames
            :text last-text
            :status status
            :signature signature-ok
            :hash (protocol-framebuffer-hash (ppu-framebuffer (nes-ppu nes)))))))

(defun run-screen-protocol (path max-frames expected-hash)
  (let ((nes (make-nes :cartridge (load-cartridge path))))
    (protocol-run-frames-until nes max-frames (constantly t))
    (let ((hash (protocol-framebuffer-hash
                 (ppu-framebuffer (nes-ppu nes)))))
      (list :passed (string-equal hash expected-hash)
            :hash hash
            :frames max-frames))))
