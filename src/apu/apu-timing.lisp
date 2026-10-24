(in-package #:cl-nes)

(defun apu-tick! (apu cycles)
  (declare (optimize (speed 3) (safety 1) (debug 1)))
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
                    nil))
              (unless (= step (1- (length events)))
                (incf (apu-frame-step apu)))))))
    ;; Frame clocks use old halt bits; reloads suppress only a same-tick
    ;; length clock. Expire markers, then apply queued halt-bit changes.
    (setf (apu-pulse-length-reload-p (apu-pulse-1 apu)) nil
          (apu-pulse-length-reload-p (apu-pulse-2 apu)) nil
          (apu-triangle-length-reload-p (apu-triangle apu)) nil
          (apu-noise-length-reload-p (apu-noise apu)) nil)
    (let ((mask (apu-length-halt-write-mask apu))
          (values (apu-length-halt-write-values apu)))
      (when (logbitp 0 mask)
        (setf (apu-envelope-loop-p
               (apu-pulse-envelope (apu-pulse-1 apu)))
              (logbitp 0 values)))
      (when (logbitp 1 mask)
        (setf (apu-envelope-loop-p
               (apu-pulse-envelope (apu-pulse-2 apu)))
              (logbitp 1 values)))
      (when (logbitp 2 mask)
        (setf (apu-triangle-control-p (apu-triangle apu))
              (logbitp 2 values)))
      (when (logbitp 3 mask)
        (setf (apu-envelope-loop-p
               (apu-noise-envelope (apu-noise apu)))
              (logbitp 3 values)))
      (setf (apu-length-halt-write-mask apu) 0
            (apu-length-halt-write-values apu) 0)))
  apu)
