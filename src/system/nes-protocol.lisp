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

(defun protocol-blargg-complete-p (status signature-p running-observed)
  (and running-observed
       (/= status #x80)
       (or (and (zerop status) signature-p)
           (/= status 0))))

(defun protocol-running-result-complete-p (result running-value running-observed)
  (and running-value running-observed (/= result running-value)))
(defun protocol-blargg-status-action (nes status signature-p running-observed
                                           reset-armed-p failure-p
                                           &key (remaining-frames 0))
  (if (and signature-p (= status #x81) reset-armed-p)
      (let ((minimum-delay-frames 7))
        (if (>= remaining-frames (1+ minimum-delay-frames))
            (progn
              ;; Seven emulated frames exceed the requested 100 ms delay.
              (loop repeat minimum-delay-frames
                    do (nes-run-frame/k nes (function identity)))
              (nes-reset! nes)
              (values :continue nil nil minimum-delay-frames))
            (values (if failure-p :complete :continue)
                    running-observed reset-armed-p 0)))
      (let* ((running-observed (or running-observed (= status #x80)))
             (reset-armed-p (or reset-armed-p (= status #x80))))
        (values (if (or (protocol-blargg-complete-p
                         status signature-p running-observed)
                        failure-p)
                    :complete
                    :continue)
                running-observed
                reset-armed-p
                0))))

(defun protocol-run-frames-until (nes max-frames predicate &key input-continuation)
  (or (loop for frame from 1 to max-frames
            do (nes-run-frame/k nes #'identity
                                :input-continuation input-continuation)
               (when (funcall predicate frame)
                 (return frame)))
      max-frames))

(defun run-accuracy-coin-protocol (path max-frames)
  "Run AccuracyCoin in Start mode and measure the two sprite result pages."
  (labels ((run-page (suite-index items)
             (let* ((page-nes (make-nes :cartridge (load-cartridge path)))
                    (page-bus (nes-bus page-nes))
                    (ram (bus-ram page-bus))
                    (frames 0))
               (labels ((run-frame (buttons)
                          (when (>= frames max-frames)
                            (error "AccuracyCoin page ~D exceeded its frame cap"
                                   suite-index))
                          (incf frames)
                          (nes-run-frame/k
                           page-nes (function identity)
                           :input-continuation
                           (lambda (current-nes)
                             (controller-set-buttons!
                              (bus-controller-1 (nes-bus current-nes))
                              buttons))))
                        (select-page (target)
                          (loop repeat 3
                                until (= (aref ram #x14) target)
                                do (run-frame +button-right+)
                                   (run-frame 0)
                                   (loop repeat 10
                                         until (= (aref ram #x14) target)
                                         do (run-frame 0)))
                          (unless (= (aref ram #x14) target)
                            (error "Could not select AccuracyCoin page ~D"
                                   target)))
                        (validate-items ()
                          (loop for item in items
                                for address = (second item)
                                for value = (aref ram address)
                                when (member value (list 0 3 #xFF))
                                  do (error
                                      "AccuracyCoin page ~D item ~A did not finish: ~X"
                                      suite-index (first item) value))))
                 (loop repeat (min 60 max-frames) do (run-frame 0))
                 (unless (and (= (aref ram #xEC) #x0A)
                              (= (aref ram #x3A) 1))
                   (error "AccuracyCoin page ~D did not pass boot sync"
                          suite-index))
                 (loop for target from 1 to suite-index
                       do (select-page target))
                 (loop repeat 12 do (run-frame 0))
                 (run-frame +button-a+)
                 (loop while (< frames max-frames)
                       do (run-frame 0))
                 (unless (and (= (aref ram #x14) suite-index)
                              (= (aref ram #x16) #xFF)
                              (= (aref ram #x3A) 1))
                   (error "AccuracyCoin page ~D did not complete"
                          suite-index))
                 (validate-items)
                 (list :suite suite-index :frames frames
                       :menu (aref ram #x14) :cursor (aref ram #x16)
                       :vblank-sync (aref ram #x3A)
                       :items
                       (loop for item in items
                             collect (list :name (first item)
                                           :address (second item)
                                           :value (aref ram (second item)))))))))
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
                       (if (<= frame-counter 180) +button-start+ 0)))))
           (results (protocol-bus-range bus #x0400 #x04ff))
           (shared-draw (bus-read bus #x03ff))
           (page-runs nil))
      (dolist (suite
               (list
                (list 18
                      (list (list "Sprite 0 Hit behavior" #x0457)
                            (list "Arbitrary Sprite zero" #x0458)
                            (list "Sprite overflow behavior" #x0459)
                            (list "Misaligned OAM behavior" #x045A)
                            (list "OAM Corruption" #x047B)
                            (list "Suddenly Resize Sprite" #x0489)
                            (list "$2002 flag timing" #x048D)
                            (list "Misaligned OAM DMA" #x0494)))
                (list 21
                      (list (list "Sprites On Scanline 0" #x0484)
                            (list "Stale Sprite Shift Regs" #x048F)
                            (list "Frozen OAM2 Increment" #x0493)
                            (list "Misaligned OAM2 Address" #x0495)))))
        (let ((page (run-page (first suite) (second suite))))
          (dolist (item (getf page :items))
            (setf (nth (- (getf item :address) #x0400) results)
                  (getf item :value)))
          (push page page-runs)))
      (list :frames frames :results results :shared-draw shared-draw
            :page-runs (nreverse page-runs)))))

(defun run-blargg-protocol (path max-frames &key mapper4-variant)
  "Run PATH using the Blargg $6000 status/signature protocol."
  (let* ((load-args (if mapper4-variant
                        (list :mapper4-variant mapper4-variant)
                        nil))
         (nes (make-nes :cartridge (apply #'load-cartridge path load-args)))
         (last-text "")
         (running-observed nil)
         (reset-armed-p t)
         (frames 0)
         (complete-p nil))
    (loop while (and (< frames max-frames) (not complete-p))
          do (nes-run-frame/k nes #'identity)
             (incf frames)
             (let* ((bus (nes-bus nes))
                    (signature-p (equal '(222 176 97)
                                        (protocol-bus-range bus #x6001 #x6003)))
                    (status (bus-read bus #x6000)))
               (setf last-text
                     (protocol-ascii-result
                      (protocol-bus-range bus #x6004 #x60ff)))
               (multiple-value-bind (action next-running-observed
                                     next-reset-armed-p delay-frames)
                   (protocol-blargg-status-action
                    nes status signature-p running-observed reset-armed-p
                    (search "FAILED" (string-upcase last-text))
                    :remaining-frames (- max-frames frames))
                 (setf running-observed next-running-observed
                       reset-armed-p next-reset-armed-p
                       complete-p (eq action :complete))
                 (incf frames delay-frames))))
    (let* ((bus (nes-bus nes))
           (signature-ok (equal '(222 176 97)
                                (protocol-bus-range bus #x6001 #x6003)))
           (status (bus-read bus #x6000)))
      (list :passed (and running-observed signature-ok (zerop status))
            :frames frames
            :text last-text
            :status status
            :signature signature-ok
            :running-observed running-observed))))

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
         (running-observed nil)
         (frames (protocol-run-frames-until
                  nes max-frames
                  (lambda (frame)
                    (declare (ignore frame))
                    (let ((result (bus-read (nes-bus nes) result-address)))
                      (when (and running-value (= result running-value))
                        (setf running-observed t))
                      (protocol-running-result-complete-p
                       result running-value running-observed)))))
         (bus (nes-bus nes))
         (result (bus-read bus result-address))
         (text (protocol-ascii-result (protocol-bus-range bus #x6004 #x60ff))))
    (list :passed (and (or (null running-value) running-observed)
                       (protocol-ram-result-p result expected))
          :frames frames :result result :result-address result-address
          :expected expected :text text
          :running-observed running-observed)))

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
            :frames frames :text text))))

(defun run-nametable-text-protocol (path max-frames expected &key
                                     (start #x2000) (columns 32) (rows 30)
                                     (tile-map #'code-char)
                                     mapper4-variant)
  (let* ((load-args (if mapper4-variant
                        (list :mapper4-variant mapper4-variant)
                        nil))
         (nes (make-nes :cartridge (apply #'load-cartridge path load-args)))
         (text "")
         (frames (protocol-run-frames-until
                  nes max-frames
                  (lambda (frame)
                    (declare (ignore frame))
                    (setf text (protocol-nametable-text
                                (nes-ppu nes) :start start :columns columns
                                :rows rows :tile-map tile-map))
                    (protocol-text-result-p text expected)))))
    (setf text (protocol-nametable-text
                (nes-ppu nes) :start start :columns columns
                :rows rows :tile-map tile-map))
    (list :passed (protocol-text-result-p text expected)
          :frames frames :text text)))

(defun run-mmc1-a12-protocol (path max-frames)
  "Run the MMC1 A12 test until its WRAM gate probe completes.

The ROM stores a sentinel in $6000 while WRAM is disabled during sprite
fetches.  It stores zero after the probe completes; a stuck sentinel means
the ROM is still waiting for the expected A12 behavior."
  (let ((nes (make-nes :cartridge (load-cartridge path)))
        (completed nil))
    (dotimes (frame max-frames)
      (nes-run-frame/k nes #'identity)
      (when (zerop (bus-read (nes-bus nes) #x6000))
        (setf completed t)
        (return)))
    (list :passed completed
          :frames max-frames
          :probe (bus-read (nes-bus nes) #x6000))))
