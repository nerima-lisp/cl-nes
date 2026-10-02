(in-package #:cl-nes)

(defun %apu-clock-pulse-timer! (pulse)
  (if (zerop (apu-pulse-timer pulse))
      (setf (apu-pulse-timer pulse) (apu-pulse-timer-period pulse)
            (apu-pulse-sequence pulse)
            (mod (1+ (apu-pulse-sequence pulse)) 8))
      (decf (apu-pulse-timer pulse))))

(defun %apu-clock-triangle-timer! (triangle)
  (if (zerop (apu-triangle-timer triangle))
      (progn
        (setf (apu-triangle-timer triangle) (apu-triangle-timer-period triangle))
        (when (and (plusp (apu-triangle-length-counter triangle))
                   (plusp (apu-triangle-linear-counter triangle)))
          (setf (apu-triangle-sequence triangle)
                (mod (1+ (apu-triangle-sequence triangle)) 32)
                (apu-triangle-dac-output triangle)
                (aref +apu-triangle-table+
                      (apu-triangle-sequence triangle)))))
      (decf (apu-triangle-timer triangle))))

(defun %apu-clock-noise-timer! (noise)
  (if (zerop (apu-noise-timer noise))
      (let* ((shift (apu-noise-shift-register noise))
             (tap (if (apu-noise-mode-p noise)
                      (logbitp 6 shift)
                      (logbitp 1 shift)))
             (feedback (if (not (eq (logbitp 0 shift) tap)) 1 0)))
        (setf (apu-noise-timer noise) (apu-noise-timer-period noise)
              (apu-noise-shift-register noise)
              (logior (ash shift -1) (ash feedback 14))))
      (decf (apu-noise-timer noise))))

(defun %apu-dmc-restart! (dmc)
  ;; $4015 reloads the DMA address and length.  It does not discard a byte
  ;; that has already been prefetched, nor does it reset the output unit.
  (setf (apu-dmc-current-address dmc) (apu-dmc-sample-address dmc)
        (apu-dmc-bytes-remaining dmc) (apu-dmc-sample-length dmc)))

(defun %apu-dmc-advance-address! (dmc)
  ;; The DMC wraps from $FFFF to $8000, unlike the sample start address
  ;; register which is restricted to $C000-$FFFF.
  (setf (apu-dmc-current-address dmc)
        (if (= (apu-dmc-current-address dmc) #xFFFF)
            #x8000
            (1+ (apu-dmc-current-address dmc)))))

(defun %apu-dmc-fetch! (apu)
  (let ((dmc (apu-dmc apu)))
    (when (and (apu-dmc-enabled-p dmc)
               (apu-dmc-sample-buffer-empty-p dmc)
               (plusp (apu-dmc-bytes-remaining dmc)))
      (let ((reader (apu-memory-reader apu)))
        ;; APUs created through MAKE-APU do not necessarily belong to a bus.
        ;; A missing reader still consumes the byte as zero, so a malformed
        ;; standalone setup cannot leave the DMC active forever.
        (setf (apu-dmc-sample-buffer dmc)
              (logand (or (and reader
                                (funcall reader (apu-dmc-current-address dmc)))
                          0)
                      #xFF)
              (apu-dmc-sample-buffer-empty-p dmc) nil)
        (%apu-dmc-advance-address! dmc)
        (decf (apu-dmc-bytes-remaining dmc))
        (if (zerop (apu-dmc-bytes-remaining dmc))
            (if (apu-dmc-loop-p dmc)
                (setf (apu-dmc-current-address dmc) (apu-dmc-sample-address dmc)
                      (apu-dmc-bytes-remaining dmc) (apu-dmc-sample-length dmc))
                (when (apu-dmc-irq-enabled-p dmc)
                  (setf (apu-dmc-irq-pending-p dmc) t))))))))

(defun %apu-clock-dmc! (dmc)
  (if (zerop (apu-dmc-timer dmc))
      (progn
        ;; The reload cycle itself emits a bit.  Store period-1 so the
        ;; countdown produces exactly the table's number of CPU clocks
        ;; between output bits.
        (setf (apu-dmc-timer dmc)
              (1- (apu-dmc-timer-period dmc)))
        (when (zerop (apu-dmc-bits-remaining dmc))
          (if (apu-dmc-sample-buffer-empty-p dmc)
              (setf (apu-dmc-silence-p dmc) t)
              (setf (apu-dmc-shift-register dmc)
                    (apu-dmc-sample-buffer dmc)
                    (apu-dmc-sample-buffer-empty-p dmc) t
                    (apu-dmc-bits-remaining dmc) 8
                    (apu-dmc-silence-p dmc) nil)))
        (unless (apu-dmc-silence-p dmc)
          (when (logbitp 0 (apu-dmc-shift-register dmc))
            (setf (apu-dmc-output dmc)
                  (min 127 (+ 2 (apu-dmc-output dmc)))))
          (unless (logbitp 0 (apu-dmc-shift-register dmc))
            (setf (apu-dmc-output dmc)
                  (max 0 (- (apu-dmc-output dmc) 2))))
          (setf (apu-dmc-shift-register dmc)
                (ash (apu-dmc-shift-register dmc) -1))
          (decf (apu-dmc-bits-remaining dmc))))
      (decf (apu-dmc-timer dmc))))
