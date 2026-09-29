(in-package #:cl-nes)

(defun %apu-write-status! (apu value)
  (let ((pulse-1 (apu-pulse-1 apu))
        (pulse-2 (apu-pulse-2 apu))
        (triangle (apu-triangle apu))
        (noise (apu-noise apu))
        (dmc (apu-dmc apu)))
    (setf (apu-dmc-irq-pending-p dmc) nil)
    (setf (apu-pulse-enabled-p pulse-1) (logbitp 0 value)
          (apu-pulse-enabled-p pulse-2) (logbitp 1 value)
          (apu-triangle-enabled-p triangle) (logbitp 2 value)
          (apu-noise-enabled-p noise) (logbitp 3 value))
    (unless (apu-pulse-enabled-p pulse-1)
      (setf (apu-pulse-length-counter pulse-1) 0
            (apu-pulse-length-reload-p pulse-1) nil))
    (unless (apu-pulse-enabled-p pulse-2)
      (setf (apu-pulse-length-counter pulse-2) 0
            (apu-pulse-length-reload-p pulse-2) nil))
    (unless (apu-triangle-enabled-p triangle)
      (setf (apu-triangle-length-counter triangle) 0
            (apu-triangle-length-reload-p triangle) nil))
    (unless (apu-noise-enabled-p noise)
      (setf (apu-noise-length-counter noise) 0
            (apu-noise-length-reload-p noise) nil))
    (setf (apu-dmc-enabled-p dmc) (logbitp 4 value))
    (if (apu-dmc-enabled-p dmc)
        (when (zerop (apu-dmc-bytes-remaining dmc))
          (%apu-dmc-restart! dmc))
        (setf (apu-dmc-bytes-remaining dmc) 0
              (apu-dmc-sample-buffer dmc) 0
              (apu-dmc-sample-buffer-empty-p dmc) t
              (apu-dmc-bits-remaining dmc) 0
              (apu-dmc-silence-p dmc) t))))

(defun %apu-write-frame-counter! (apu value)
  (setf (apu-frame-last-five-step-p apu) (logbitp 7 value)
        (apu-frame-reset-delay apu)
        (if (zerop (apu-cycle-parity apu)) 3 4)
        (apu-frame-reset-five-step-p apu) (logbitp 7 value)
        (apu-frame-reset-irq-inhibit-p apu) (logbitp 6 value)
        ;; The inhibit bit takes effect at the write.  The
        ;; sequencer mode itself still changes after its
        ;; hardware reset delay.
        (apu-frame-irq-inhibit-p apu) (logbitp 6 value))
  (when (logbitp 6 value)
    (setf (apu-frame-irq-pending-p apu) nil
          (apu-frame-irq-repeat-count apu) 0)))

(defun apu-read-register (apu address)
  (case (logand address #xFFFF)
    (#x4015
     (let ((value (logior (if (plusp (apu-pulse-length-counter (apu-pulse-1 apu))) 1 0)
                          (if (plusp (apu-pulse-length-counter (apu-pulse-2 apu))) 2 0)
                          (if (plusp (apu-triangle-length-counter (apu-triangle apu))) 4 0)
                          (if (plusp (apu-noise-length-counter (apu-noise apu))) 8 0)
                          (if (or (plusp (apu-dmc-bytes-remaining (apu-dmc apu)))
                                  (and (plusp (apu-dmc-bits-remaining (apu-dmc apu)))
                                       (not (apu-dmc-silence-p (apu-dmc apu)))))
                              16
                              0)
                          (if (apu-frame-irq-pending-p apu) #x40 0)
                          (if (apu-dmc-irq-pending-p (apu-dmc apu)) #x80 0))))
       ;; $4015 reads acknowledge the frame IRQ latch.  The short
       ;; end-of-sequence visibility window is only for clocks before the
       ;; acknowledge; it must not recreate an IRQ after the read.
       (setf (apu-frame-irq-pending-p apu) nil
             (apu-frame-irq-repeat-count apu) 0)
       value))
    (otherwise nil)))

(defun apu-irq-pending-p (apu)
  (or (apu-frame-irq-pending-p apu)
      (apu-dmc-irq-pending-p (apu-dmc apu))))
