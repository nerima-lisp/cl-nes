(in-package #:cl-nes)

(defparameter +apu-console-reset-register-specs+
  '((pulse-1 apu-pulse-1
      ((apu-pulse-duty channel)
       (apu-pulse-timer-period channel)
       (apu-pulse-sweep-enabled-p channel)
       (apu-pulse-sweep-period channel)
       (apu-pulse-sweep-negate-p channel)
       (apu-pulse-sweep-shift channel)
       (apu-envelope-loop-p (apu-pulse-envelope channel))
       (apu-envelope-constant-volume-p (apu-pulse-envelope channel))
       (apu-envelope-volume (apu-pulse-envelope channel))))
    (pulse-2 apu-pulse-2
      ((apu-pulse-duty channel)
       (apu-pulse-timer-period channel)
       (apu-pulse-sweep-enabled-p channel)
       (apu-pulse-sweep-period channel)
       (apu-pulse-sweep-negate-p channel)
       (apu-pulse-sweep-shift channel)
       (apu-envelope-loop-p (apu-pulse-envelope channel))
       (apu-envelope-constant-volume-p (apu-pulse-envelope channel))
       (apu-envelope-volume (apu-pulse-envelope channel))))
    (triangle apu-triangle
      ((apu-triangle-timer-period channel)
       (apu-triangle-linear-reload-value channel)
       (apu-triangle-control-p channel)))
    (noise apu-noise
      ((apu-noise-mode-p channel)
       (apu-noise-timer-period channel)
       (apu-envelope-loop-p (apu-noise-envelope channel))
       (apu-envelope-constant-volume-p (apu-noise-envelope channel))
       (apu-envelope-volume (apu-noise-envelope channel))))
    (dmc apu-dmc
      ((apu-dmc-irq-enabled-p channel)
       (apu-dmc-loop-p channel)
       (apu-dmc-rate-index channel)
       (apu-dmc-timer-period channel)
       (apu-dmc-output channel)
       (apu-dmc-sample-address channel)
       (apu-dmc-sample-length channel)))))

(defparameter +apu-console-reset-frame-restore-specs+
  '(((apu-frame-last-five-step-p apu) five-step)
    ((apu-frame-reset-delay apu) 3)
    ((apu-frame-reset-five-step-p apu) five-step)
    ((apu-frame-reset-irq-inhibit-p apu) nil)))
