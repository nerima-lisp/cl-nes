(in-package #:cl-nes)

;; Pulse, triangle, and noise timer transitions.  DMC sample-unit state lives
;; in APU-DMC-HELPERS.LISP so timing orchestration can depend on a narrower
;; channel-timer surface here.

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
                (mod (1+ (apu-triangle-sequence triangle)) 32))))
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
