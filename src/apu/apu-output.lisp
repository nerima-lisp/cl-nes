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

(defun apu-mix (apu)
  "Return the current nonlinear hardware mixer output in the range 0..1."
  (let* ((pulse (+ (%apu-pulse-output (apu-pulse-1 apu) t)
                   (%apu-pulse-output (apu-pulse-2 apu) nil)))
         (tnd (+ (* 3 (%apu-triangle-output (apu-triangle apu)))
                 (* 2 (%apu-noise-output (apu-noise apu)))
                 (apu-dmc-output (apu-dmc apu)))))
    (+ (aref +apu-pulse-mixer-table+ pulse)
       (aref +apu-tnd-mixer-table+ tnd))))
