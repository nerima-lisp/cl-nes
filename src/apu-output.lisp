(in-package #:cl-nes)

(defun %apu-pulse-output (pulse first-p)
  (let* ((envelope (apu-pulse-envelope pulse))
         (timer (apu-pulse-timer-period pulse))
         (target (%apu-pulse-sweep-target pulse first-p)))
    (if (or (not (apu-pulse-enabled-p pulse))
            (zerop (apu-pulse-length-counter pulse))
            (< timer 8)
            (> target #x7FF)
            (zerop (aref (aref +apu-pulse-duty-table+ (apu-pulse-duty pulse))
                         (apu-pulse-sequence pulse))))
        0
        (%apu-envelope-output envelope))))

(defun %apu-triangle-output (triangle)
  (if (or (not (apu-triangle-enabled-p triangle))
          (zerop (apu-triangle-length-counter triangle))
          (zerop (apu-triangle-linear-counter triangle)))
      0
      (aref +apu-triangle-table+ (apu-triangle-sequence triangle))))

(defun %apu-noise-output (noise)
  (if (or (not (apu-noise-enabled-p noise))
          (zerop (apu-noise-length-counter noise))
          (logbitp 0 (apu-noise-shift-register noise)))
      0
      (%apu-envelope-output (apu-noise-envelope noise))))

(defun apu-sample (apu)
  "Return the current headless mixer output as an unsigned 8-bit integer."
  (let* ((pulse (+ (%apu-pulse-output (apu-pulse-1 apu) t)
                   (%apu-pulse-output (apu-pulse-2 apu) nil)))
         (triangle (%apu-triangle-output (apu-triangle apu)))
         (noise (%apu-noise-output (apu-noise apu)))
         (dmc (apu-dmc-output (apu-dmc apu))))
    (min 255 (+ (* 4 pulse) (* 2 triangle) noise dmc))))
