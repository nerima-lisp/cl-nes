(in-package #:cl-nes)

(defun %apu-write-status! (apu value)
  (let ((pulse-1 (apu-pulse-1 apu))
        (pulse-2 (apu-pulse-2 apu))
        (triangle (apu-triangle apu))
        (noise (apu-noise apu))
        (dmc (apu-dmc apu))
        (enabled-p (logbitp 4 value)))
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
    (setf (apu-dmc-enabled-p dmc) enabled-p)
    (when (and enabled-p
               (zerop (apu-dmc-bytes-remaining dmc)))
      (%apu-dmc-restart! dmc))
    (setf (apu-dmc-status-write-pending-p dmc) t
          (apu-dmc-status-write-enabled-p dmc) enabled-p
          (apu-dmc-status-write-phase dmc) (mod (apu-cycle-parity apu) 2)
          (apu-dmc-status-write-origin-cycle dmc)
          (1+ (apu-cpu-cycle-index apu)))))

(defun %apu-write-frame-counter! (apu value)
  (when (= (apu-frame-reset-delay apu) 1)
    (%apu-apply-frame-reset! apu))
  ;; The write cycle is counted immediately; 5/4 ticks implement the 4/3-cycle delay.
  (setf (apu-frame-last-five-step-p apu) (logbitp 7 value)
        (apu-frame-reset-delay apu)
        (if (zerop (apu-cycle-parity apu)) 5 4)
        (apu-frame-event-offset apu) (if (zerop (apu-cycle-parity apu)) 1 0)
        (apu-frame-reset-five-step-p apu) (logbitp 7 value)
        (apu-frame-reset-irq-inhibit-p apu) (logbitp 6 value)
        (apu-frame-irq-inhibit-p apu) (logbitp 6 value))
  (when (logbitp 6 value)
    (setf (apu-frame-irq-pending-p apu) nil
          (apu-frame-irq-repeat-count apu) 0
          (apu-frame-irq-clear-pending-p apu) nil)))

(defun apu-read-register (apu address)
  (case (logand address #xFFFF)
    (#x4015
     (when (and (= (apu-frame-reset-delay apu) 1)
                (apu-frame-reset-five-step-p apu))
       (%apu-apply-frame-reset! apu))
     (let ((value
             (logior
              (if (plusp (apu-pulse-length-counter (apu-pulse-1 apu)))
                  1
                  0)
              (if (plusp (apu-pulse-length-counter (apu-pulse-2 apu)))
                  2
                  0)
              (if (plusp (apu-triangle-length-counter (apu-triangle apu)))
                  4
                  0)
              (if (plusp (apu-noise-length-counter (apu-noise apu)))
                  8
                  0)
              (if (plusp (apu-dmc-bytes-remaining (apu-dmc apu)))
                  16
                  0)
              (if (apu-frame-irq-pending-p apu)
                  #x40
                  0)
              (if (apu-dmc-irq-pending-p (apu-dmc apu))
                  #x80
                  0))))
        (when (apu-frame-irq-pending-p apu)
          (setf (apu-frame-irq-clear-pending-p apu) t))
        value))
    (otherwise nil)))

(defun apu-irq-pending-p (apu)
  (or (apu-dmc-irq-pending-p (apu-dmc apu))
      (and (apu-frame-irq-pending-p apu)
           (<= (apu-frame-irq-repeat-count apu) 1)
           (not (apu-frame-irq-inhibit-p apu)))))
