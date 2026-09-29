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

(defun protocol-nametable-text (ppu &key (start #x2000) (columns 32)
                                       (rows 30) (tile-map #'code-char))
  "Read a nametable region and decode its tile numbers with TILE-MAP.

TILE-MAP receives one tile number and must return a character or NIL.  This
keeps screen protocols independent of the ROM's font tile numbering while
allowing tests to supply the mapping established by that ROM's source."
  (with-output-to-string (text)
    (dotimes (row rows)
      (dotimes (column columns)
        (let ((character (funcall tile-map
                                  (ppu-read-vram ppu (+ start column
                                                        (* row columns))))))
          (write-char (or character #\.) text)))
      (unless (= row (1- rows))
        (terpri text)))))

(defun protocol-ram-result-p (actual expected)
  "Return true when a ROM result byte ACTUAL equals EXPECTED."
  (= actual expected))

(defun protocol-text-result-p (text expected)
  "Return true when TEXT contains the expected ROM result marker."
  (not (null (search (string-upcase expected) (string-upcase text)))))

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

(defun run-ram-result-protocol (path max-frames result-address expected
                                &key mapper4-variant running-value)
  "Run PATH and judge the byte at RESULT-ADDRESS against EXPECTED.

This is the protocol used by the older screen/beep ROMs.  Their result byte
is the source of truth; screen text and beep count are redundant diagnostics.
RUNNING-VALUE, when supplied, stops the frame loop once the ROM leaves that
value."
  (let* ((load-args (if mapper4-variant
                        (list :mapper4-variant mapper4-variant)
                        nil))
         (nes (make-nes :cartridge (apply #'load-cartridge path load-args)))
         (frames (protocol-run-frames-until
                  nes max-frames
                  (lambda (frame)
                    (declare (ignore frame))
                    (and running-value
                         (/= (bus-read (nes-bus nes) result-address)
                             running-value)))))
         (bus (nes-bus nes))
         (result (bus-read bus result-address))
         (text (protocol-ascii-result (protocol-bus-range bus #x6004 #x60ff))))
    (list :passed (protocol-ram-result-p result expected)
          :frames frames :result result :result-address result-address
          :expected expected :text text
          :hash (protocol-framebuffer-hash (ppu-framebuffer (nes-ppu nes))))))

(defun run-text-progress-protocol (path max-frames expected &key mapper4-variant)
  "Run a legacy ROM whose textual result is exposed at the Blargg text port."
  (let* ((load-args (if mapper4-variant
                        (list :mapper4-variant mapper4-variant)
                        nil))
         (nes (make-nes :cartridge (apply #'load-cartridge path load-args)))
         (frames (protocol-run-frames-until
                  nes max-frames
                  (lambda (frame)
                    (declare (ignore frame))
                    (protocol-text-result-p
                     (protocol-ascii-result
                      (protocol-bus-range (nes-bus nes) #x6004 #x60ff))
                     expected)))))
    (let ((text (protocol-ascii-result
                 (protocol-bus-range (nes-bus nes) #x6004 #x60ff))))
      (list :passed (protocol-text-result-p text expected)
            :frames frames :text text
            :hash (protocol-framebuffer-hash
                   (ppu-framebuffer (nes-ppu nes)))))))

(defun run-screen-protocol (path max-frames expected-hash)
  (let ((nes (make-nes :cartridge (load-cartridge path))))
    (protocol-run-frames-until nes max-frames (constantly t))
    (let ((hash (protocol-framebuffer-hash
                 (ppu-framebuffer (nes-ppu nes)))))
      (list :passed (string-equal hash expected-hash)
            :hash hash
            :frames max-frames))))
