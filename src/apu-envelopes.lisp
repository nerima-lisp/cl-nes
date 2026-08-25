(in-package #:cl-nes)

;; Envelope, length-counter, and pulse-sweep transitions.  Frame sequencing
;; invokes these primitives, while register decoding remains in
;; APU-REGISTERS.LISP.

(defun %apu-length-value (value)
  (aref +apu-length-table+ (logand (ash value -3) #x1F)))

(defun %apu-envelope-output (envelope)
  (if (apu-envelope-constant-volume-p envelope)
      (apu-envelope-volume envelope)
      (apu-envelope-decay envelope)))

(defun %apu-clock-envelope! (envelope)
  (if (apu-envelope-start-p envelope)
      (setf (apu-envelope-start-p envelope) nil
            (apu-envelope-decay envelope) 15
            (apu-envelope-divider envelope) (apu-envelope-volume envelope))
      (if (zerop (apu-envelope-divider envelope))
          (progn
            (setf (apu-envelope-divider envelope)
                  (apu-envelope-volume envelope))
            (if (plusp (apu-envelope-decay envelope))
                (decf (apu-envelope-decay envelope))
                (when (apu-envelope-loop-p envelope)
                  (setf (apu-envelope-decay envelope) 15))))
          (decf (apu-envelope-divider envelope)))))

(defun %apu-clock-length! (channel halt-p)
  (when (not halt-p)
    (typecase channel
      (apu-pulse
       (when (plusp (apu-pulse-length-counter channel))
         (decf (apu-pulse-length-counter channel))))
      (apu-triangle
       (when (plusp (apu-triangle-length-counter channel))
         (decf (apu-triangle-length-counter channel))))
      (apu-noise
       (when (plusp (apu-noise-length-counter channel))
         (decf (apu-noise-length-counter channel)))))))

(defun %apu-pulse-sweep-target (pulse first-p)
  (let* ((timer (apu-pulse-timer-period pulse))
         (change (ash timer (- (apu-pulse-sweep-shift pulse))))
         (target (if (apu-pulse-sweep-negate-p pulse)
                     (- timer change (if first-p 1 0))
                     (+ timer change))))
    target))

(defun %apu-clock-sweep! (pulse first-p)
  (let ((reload (apu-pulse-sweep-reload-p pulse))
        (divider (apu-pulse-sweep-divider pulse)))
    (when (and (apu-pulse-sweep-enabled-p pulse)
               (plusp (apu-pulse-sweep-shift pulse))
               (zerop divider))
      (let ((target (%apu-pulse-sweep-target pulse first-p)))
        (when (and (<= 0 target) (<= target #x7FF))
          (setf (apu-pulse-timer-period pulse) target))))
    (if (or reload (zerop divider))
        (setf (apu-pulse-sweep-divider pulse)
              (apu-pulse-sweep-period pulse))
        (decf (apu-pulse-sweep-divider pulse)))
    (when reload
      (setf (apu-pulse-sweep-reload-p pulse) nil))))
