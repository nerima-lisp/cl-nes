(in-package #:cl-nes)

;; Console reset preserves the register latches that are distinct from the
;; ordinary channel state reset.  Keeping this boundary separate from the
;; per-cycle timing code makes the APU lifecycle easier to audit.

(defun apu-console-reset! (apu)
  "Reset console-visible APU state while retaining the last $4017 mode.

Power-up and a subsequent RESET differ on the NES: RESET clears the frame
counter's IRQ inhibit state but repeats the previously selected four-/five-
step mode.  The channel register values remain latched across RESET, while
the ordinary APU reset clears the channel's active state."
  (let* ((pulse-1 (apu-pulse-1 apu))
         (pulse-2 (apu-pulse-2 apu))
         (triangle (apu-triangle apu))
         (noise (apu-noise apu))
         (dmc (apu-dmc apu))
         (five-step (apu-frame-last-five-step-p apu))
         (pulse-1-registers
           (list (apu-pulse-duty pulse-1)
                 (apu-pulse-timer-period pulse-1)
                 (apu-pulse-sweep-enabled-p pulse-1)
                 (apu-pulse-sweep-period pulse-1)
                 (apu-pulse-sweep-negate-p pulse-1)
                 (apu-pulse-sweep-shift pulse-1)
                 (apu-envelope-loop-p (apu-pulse-envelope pulse-1))
                 (apu-envelope-constant-volume-p
                   (apu-pulse-envelope pulse-1))
                 (apu-envelope-volume (apu-pulse-envelope pulse-1))))
         (pulse-2-registers
           (list (apu-pulse-duty pulse-2)
                 (apu-pulse-timer-period pulse-2)
                 (apu-pulse-sweep-enabled-p pulse-2)
                 (apu-pulse-sweep-period pulse-2)
                 (apu-pulse-sweep-negate-p pulse-2)
                 (apu-pulse-sweep-shift pulse-2)
                 (apu-envelope-loop-p (apu-pulse-envelope pulse-2))
                 (apu-envelope-constant-volume-p
                   (apu-pulse-envelope pulse-2))
                 (apu-envelope-volume (apu-pulse-envelope pulse-2))))
         (triangle-registers
           (list (apu-triangle-timer-period triangle)
                 (apu-triangle-linear-reload-value triangle)
                 (apu-triangle-control-p triangle)))
         (noise-registers
           (list (apu-noise-mode-p noise)
                 (apu-noise-timer-period noise)
                 (apu-envelope-loop-p (apu-noise-envelope noise))
                 (apu-envelope-constant-volume-p
                   (apu-noise-envelope noise))
                 (apu-envelope-volume (apu-noise-envelope noise))))
         (dmc-registers
           (list (apu-dmc-irq-enabled-p dmc)
                 (apu-dmc-loop-p dmc)
                 (apu-dmc-rate-index dmc)
                 (apu-dmc-timer-period dmc)
                 (apu-dmc-output dmc)
                 (apu-dmc-sample-address dmc)
                 (apu-dmc-sample-length dmc))))
    (apu-reset! apu)
    (destructuring-bind (duty timer-period sweep-enabled sweep-period
                         sweep-negate sweep-shift envelope-loop
                         envelope-constant-volume envelope-volume)
        pulse-1-registers
      (let ((pulse (apu-pulse-1 apu)))
        (setf (apu-pulse-duty pulse) duty
              (apu-pulse-timer-period pulse) timer-period
              (apu-pulse-sweep-enabled-p pulse) sweep-enabled
              (apu-pulse-sweep-period pulse) sweep-period
              (apu-pulse-sweep-negate-p pulse) sweep-negate
              (apu-pulse-sweep-shift pulse) sweep-shift
              (apu-envelope-loop-p (apu-pulse-envelope pulse)) envelope-loop
              (apu-envelope-constant-volume-p
                (apu-pulse-envelope pulse)) envelope-constant-volume
              (apu-envelope-volume (apu-pulse-envelope pulse))
              envelope-volume)))
    (destructuring-bind (duty timer-period sweep-enabled sweep-period
                         sweep-negate sweep-shift envelope-loop
                         envelope-constant-volume envelope-volume)
        pulse-2-registers
      (let ((pulse (apu-pulse-2 apu)))
        (setf (apu-pulse-duty pulse) duty
              (apu-pulse-timer-period pulse) timer-period
              (apu-pulse-sweep-enabled-p pulse) sweep-enabled
              (apu-pulse-sweep-period pulse) sweep-period
              (apu-pulse-sweep-negate-p pulse) sweep-negate
              (apu-pulse-sweep-shift pulse) sweep-shift
              (apu-envelope-loop-p (apu-pulse-envelope pulse)) envelope-loop
              (apu-envelope-constant-volume-p
                (apu-pulse-envelope pulse)) envelope-constant-volume
              (apu-envelope-volume (apu-pulse-envelope pulse))
              envelope-volume)))
    (destructuring-bind (timer-period linear-reload-value control)
        triangle-registers
      (let ((triangle (apu-triangle apu)))
        (setf (apu-triangle-timer-period triangle) timer-period
              (apu-triangle-linear-reload-value triangle) linear-reload-value
              (apu-triangle-control-p triangle) control)))
    (destructuring-bind (mode timer-period envelope-loop
                         envelope-constant-volume envelope-volume)
        noise-registers
      (let ((noise (apu-noise apu)))
        (setf (apu-noise-mode-p noise) mode
              (apu-noise-timer-period noise) timer-period
              (apu-envelope-loop-p (apu-noise-envelope noise)) envelope-loop
              (apu-envelope-constant-volume-p
                (apu-noise-envelope noise)) envelope-constant-volume
              (apu-envelope-volume (apu-noise-envelope noise))
              envelope-volume)))
    (destructuring-bind (irq-enabled loop rate-index timer-period output
                         sample-address sample-length)
        dmc-registers
      (let ((dmc (apu-dmc apu)))
        (setf (apu-dmc-irq-enabled-p dmc) irq-enabled
              (apu-dmc-loop-p dmc) loop
              (apu-dmc-rate-index dmc) rate-index
              (apu-dmc-timer-period dmc) timer-period
              (apu-dmc-output dmc) output
              (apu-dmc-sample-address dmc) sample-address
              (apu-dmc-sample-length dmc) sample-length)))
    (setf (apu-frame-last-five-step-p apu) five-step
          (apu-frame-reset-delay apu) 3
          (apu-frame-reset-five-step-p apu) five-step
          (apu-frame-reset-irq-inhibit-p apu) nil)
    apu))
