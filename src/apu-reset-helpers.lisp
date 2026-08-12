(in-package #:cl-nes)

(defun %apu-reset-frame-state! (apu)
  (setf (apu-frame-cycle apu) 0
        (apu-frame-step apu) 0
        (apu-five-step-p apu) nil
        (apu-frame-last-five-step-p apu) nil
        (apu-frame-irq-inhibit-p apu) nil
        (apu-frame-irq-pending-p apu) nil
        (apu-frame-irq-repeat-count apu) 0
        (apu-frame-tail-step apu) 0
        (apu-frame-reset-delay apu) 0
        (apu-frame-reset-five-step-p apu) nil
        (apu-frame-reset-irq-inhibit-p apu) nil
        (apu-cycle-parity apu) 0)
  apu)

(defun %apu-reset-envelope! (envelope)
  (setf (apu-envelope-loop-p envelope) nil
        (apu-envelope-constant-volume-p envelope) nil
        (apu-envelope-volume envelope) 0
        (apu-envelope-start-p envelope) nil
        (apu-envelope-divider envelope) 0
        (apu-envelope-decay envelope) 0)
  envelope)

(defun %apu-reset-pulse! (pulse)
  (setf (apu-pulse-enabled-p pulse) nil
        (apu-pulse-duty pulse) 0
        (apu-pulse-sequence pulse) 0
        (apu-pulse-timer pulse) 0
        (apu-pulse-timer-period pulse) 0
        (apu-pulse-length-counter pulse) 0
        (apu-pulse-sweep-enabled-p pulse) nil
        (apu-pulse-sweep-period pulse) 0
        (apu-pulse-sweep-negate-p pulse) nil
        (apu-pulse-sweep-shift pulse) 0
        (apu-pulse-sweep-divider pulse) 0
        (apu-pulse-sweep-reload-p pulse) nil
        (apu-pulse-sweep-mute-p pulse) nil)
  (%apu-reset-envelope! (apu-pulse-envelope pulse))
  pulse)

(defun %apu-reset-triangle! (triangle)
  (setf (apu-triangle-enabled-p triangle) nil
        (apu-triangle-timer triangle) 0
        (apu-triangle-timer-period triangle) 0
        (apu-triangle-length-counter triangle) 0
        (apu-triangle-linear-counter triangle) 0
        (apu-triangle-linear-reload-value triangle) 0
        (apu-triangle-linear-reload-p triangle) nil
        (apu-triangle-control-p triangle) nil
        (apu-triangle-sequence triangle) 0)
  triangle)

(defun %apu-reset-noise! (noise)
  (setf (apu-noise-enabled-p noise) nil
        (apu-noise-mode-p noise) nil
        (apu-noise-timer noise) 0
        (apu-noise-timer-period noise) 4
        (apu-noise-length-counter noise) 0
        (apu-noise-shift-register noise) 1)
  (%apu-reset-envelope! (apu-noise-envelope noise))
  noise)

(defun %apu-reset-dmc! (dmc)
  (setf (apu-dmc-enabled-p dmc) nil
        (apu-dmc-irq-enabled-p dmc) nil
        (apu-dmc-loop-p dmc) nil
        (apu-dmc-irq-pending-p dmc) nil
        (apu-dmc-rate-index dmc) 0
        (apu-dmc-timer dmc) 0
        (apu-dmc-timer-period dmc) 428
        (apu-dmc-output dmc) 0
        (apu-dmc-sample-address dmc) #xC000
        (apu-dmc-current-address dmc) #xC000
        (apu-dmc-sample-length dmc) 1
        (apu-dmc-bytes-remaining dmc) 0
        (apu-dmc-sample-buffer dmc) 0
        (apu-dmc-sample-buffer-empty-p dmc) t
        (apu-dmc-shift-register dmc) 0
        (apu-dmc-bits-remaining dmc) 0
        (apu-dmc-silence-p dmc) t)
  dmc)
