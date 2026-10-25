(in-package #:cl-nes)

(defun %apu-clock-quarter-frame! (apu)
  (%apu-clock-envelope! (apu-pulse-envelope (apu-pulse-1 apu)))
  (%apu-clock-envelope! (apu-pulse-envelope (apu-pulse-2 apu)))
  (%apu-clock-envelope! (apu-noise-envelope (apu-noise apu)))
  (let ((triangle (apu-triangle apu)))
    (if (apu-triangle-linear-reload-p triangle)
        (setf (apu-triangle-linear-counter triangle)
              (apu-triangle-linear-reload-value triangle))
        (when (plusp (apu-triangle-linear-counter triangle))
          (decf (apu-triangle-linear-counter triangle))))
    (unless (apu-triangle-control-p triangle)
      (setf (apu-triangle-linear-reload-p triangle) nil))))

(defun %apu-clock-half-frame! (apu)
  (let ((pulse-1 (apu-pulse-1 apu))
        (pulse-2 (apu-pulse-2 apu))
        (triangle (apu-triangle apu))
        (noise (apu-noise apu)))
    (%apu-clock-length! pulse-1 (apu-envelope-loop-p (apu-pulse-envelope pulse-1)))
    (%apu-clock-length! pulse-2 (apu-envelope-loop-p (apu-pulse-envelope pulse-2)))
    (%apu-clock-length! triangle (apu-triangle-control-p triangle))
    (%apu-clock-length! noise (apu-envelope-loop-p (apu-noise-envelope noise)))
    (%apu-clock-sweep! pulse-1 t)
    (%apu-clock-sweep! pulse-2 nil)))

(defun %apu-length-clock-on-next-tick-p (apu)
  (cond
    ((= (apu-frame-reset-delay apu) 1)
     (apu-frame-reset-five-step-p apu))
    ((plusp (apu-frame-tail-step apu))
     nil)
    (t
     (let* ((events (if (apu-five-step-p apu)
                        +apu-five-step-events+
                        +apu-four-step-events+))
            (step (apu-frame-step apu)))
       (and (< step (length events))
            (>= (1+ (apu-frame-cycle apu)) (aref events step))
            (or (= step 1)
                (and (= step 3) (not (apu-five-step-p apu)))
                (and (= step 4) (apu-five-step-p apu))))))))

(defun %apu-frame-event! (apu)
  (case (apu-frame-step apu)
    (0 (%apu-clock-quarter-frame! apu))
    (1 (%apu-clock-quarter-frame! apu)
       (%apu-clock-half-frame! apu))
    (2 (%apu-clock-quarter-frame! apu))
    ;; The four-step terminal event clocks the quarter- and half-frame units.
    (3 (unless (apu-five-step-p apu)
         (%apu-clock-quarter-frame! apu)
         (%apu-clock-half-frame! apu)
         (setf (apu-frame-event-offset apu) 0
               (apu-frame-tail-step apu) 1)))
    ;; The fifth five-step event clocks quarter/half-frame units before reset.
    (4 (%apu-clock-quarter-frame! apu)
       (%apu-clock-half-frame! apu)))
  apu)

(defun %apu-apply-frame-reset! (apu)
  ;; Length reloads only suppress a half-frame clock on their own sequencer event.
  (setf (apu-pulse-length-reload-p (apu-pulse-1 apu)) nil
        (apu-pulse-length-reload-p (apu-pulse-2 apu)) nil
        (apu-triangle-length-reload-p (apu-triangle apu)) nil
        (apu-noise-length-reload-p (apu-noise apu)) nil)
  (let ((event-offset (apu-frame-event-offset apu)))
    (setf (apu-frame-cycle apu) event-offset
          (apu-frame-step apu) 0
          (apu-five-step-p apu) (apu-frame-reset-five-step-p apu)
          (apu-frame-irq-inhibit-p apu) (apu-frame-reset-irq-inhibit-p apu)
          (apu-frame-event-offset apu) (if (apu-frame-reset-five-step-p apu)
                                           0
                                           event-offset)
          (apu-frame-irq-cycle apu) 0
          (apu-frame-irq-repeat-count apu) 0
          (apu-frame-tail-step apu) 0
          (apu-frame-reset-delay apu) 0))
  (when (apu-five-step-p apu)
    (%apu-clock-quarter-frame! apu)
    (%apu-clock-half-frame! apu))
  apu)
