(in-package #:cl-nes)

(defun %apu-merge-timer-low (period value)
  (logior (logand period #x700)
          value))

(%define-apu-envelope-control-writers)
(%define-apu-timer-high-writers)

(defun %apu-write-pulse-sweep! (pulse value)
  (setf (apu-pulse-sweep-enabled-p pulse) (logbitp 7 value)
        (apu-pulse-sweep-period pulse) (1+ (ldb (byte 3 4) value))
        (apu-pulse-sweep-negate-p pulse) (logbitp 3 value)
        (apu-pulse-sweep-shift pulse) (logand value 7)
        (apu-pulse-sweep-reload-p pulse) t))

(defun %apu-write-triangle-control! (triangle value)
  (setf (apu-triangle-control-p triangle) (logbitp 7 value)
        (apu-triangle-linear-reload-value triangle) (logand value #x7F)))

(defun %apu-write-noise-period! (noise value)
  (setf (apu-noise-mode-p noise) (logbitp 7 value)
        (apu-noise-timer-period noise)
        (aref +apu-noise-period-table+ (logand value #x0F))))

(defun %apu-write-dmc-control! (dmc value)
  (setf (apu-dmc-irq-enabled-p dmc) (logbitp 7 value)
        (apu-dmc-loop-p dmc) (logbitp 6 value)
        (apu-dmc-rate-index dmc) (logand value #x0F)
        (apu-dmc-timer-period dmc)
        (aref +apu-dmc-rate-table+ (logand value #x0F)))
  (unless (apu-dmc-irq-enabled-p dmc)
    (setf (apu-dmc-irq-pending-p dmc) nil)))

(defun %apu-write-frame-counter! (apu value)
  (setf (apu-frame-last-five-step-p apu) (logbitp 7 value)
        (apu-frame-reset-delay apu)
        (if (zerop (apu-cycle-parity apu)) 3 4)
        (apu-frame-reset-five-step-p apu) (logbitp 7 value)
        (apu-frame-reset-irq-inhibit-p apu) (logbitp 6 value)
        ;; The inhibit bit takes effect at the write.  The sequencer mode
        ;; itself still changes after its hardware reset delay.
        (apu-frame-irq-inhibit-p apu) (logbitp 6 value))
  (when (logbitp 6 value)
    (setf (apu-frame-irq-pending-p apu) nil
          (apu-frame-irq-repeat-count apu) 0)))

(defun %apu-write-status-dmc! (dmc value)
  (setf (apu-dmc-irq-pending-p dmc) nil
        (apu-dmc-enabled-p dmc) (logbitp 4 value))
(if (apu-dmc-enabled-p dmc)
      (when (zerop (apu-dmc-bytes-remaining dmc))
        (%apu-dmc-restart! dmc))
      (setf (apu-dmc-bytes-remaining dmc) 0
            (apu-dmc-sample-buffer dmc) 0
            (apu-dmc-sample-buffer-empty-p dmc) t
            (apu-dmc-bits-remaining dmc) 0
            (apu-dmc-silence-p dmc) t)))

(defun %apu-write-status! (apu value)
  (%apu-write-status-channels! apu value)
  (%apu-write-status-dmc! (apu-dmc apu) value))
