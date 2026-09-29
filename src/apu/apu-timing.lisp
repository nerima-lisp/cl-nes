(in-package #:cl-nes)

(defun apu-tick! (apu cycles)
  (loop repeat (max 0 cycles) do
    (when (plusp (apu-frame-reset-delay apu))
      (decf (apu-frame-reset-delay apu))
      (when (zerop (apu-frame-reset-delay apu))
        (%apu-apply-frame-reset! apu)))
    (when (and (plusp (apu-frame-irq-repeat-count apu))
               (not (apu-frame-irq-inhibit-p apu)))
      (setf (apu-frame-irq-pending-p apu) t)
      (decf (apu-frame-irq-repeat-count apu)))
    (incf (apu-cycle-parity apu))
    (%apu-clock-dmc! (apu-dmc apu))
    (%apu-dmc-fetch! apu)
    (%apu-clock-triangle-timer! (apu-triangle apu))
    (when (= (apu-cycle-parity apu) 2)
      (setf (apu-cycle-parity apu) 0)
      (%apu-clock-pulse-timer! (apu-pulse-1 apu))
      (%apu-clock-pulse-timer! (apu-pulse-2 apu))
      (%apu-clock-noise-timer! (apu-noise apu)))
    (incf (apu-frame-cycle apu))
    (if (plusp (apu-frame-tail-step apu))
        (case (apu-frame-tail-step apu)
          (1
           (%apu-clock-quarter-frame! apu)
           (%apu-clock-half-frame! apu)
           (unless (apu-frame-irq-inhibit-p apu)
             (setf (apu-frame-irq-pending-p apu) t))
           (setf (apu-frame-tail-step apu) 2))
          (2
           (unless (apu-frame-irq-inhibit-p apu)
             (setf (apu-frame-irq-pending-p apu) t))
           (setf (apu-frame-tail-step apu) 0
                 (apu-frame-step apu) 0
                 ;; Leave the two tail clocks in the elapsed count.  With
                 ;; the first event at 7458, this makes the next step land
                 ;; at the documented 37289-clock boundary.
                 (apu-frame-cycle apu) 1)))
        (let* ((events (if (apu-five-step-p apu)
                           +apu-five-step-events+
                           +apu-four-step-events+))
               (step (apu-frame-step apu)))
          (let ((event-cycle (aref events step)))
            (when (>= (apu-frame-cycle apu) event-cycle)
              (%apu-frame-event! apu)
              (when (= step (1- (length events)))
                (if (apu-five-step-p apu)
                    (setf (apu-frame-step apu) 0
                          (apu-frame-cycle apu) 0)
                    ;; Four-step mode continues through FRAME-TAIL-STEP.
                    nil))
              (unless (= step (1- (length events)))
                (incf (apu-frame-step apu))))))))
    (when (plusp (apu-frame-irq-clear-delay apu))
      (decf (apu-frame-irq-clear-delay apu))
      (when (zerop (apu-frame-irq-clear-delay apu))
        (setf (apu-frame-irq-pending-p apu) nil)))
  apu)
