(in-package #:cl-nes)

(defun apu-tick! (apu cycles)
  (declare (optimize (speed 3) (safety 1) (debug 1)))
  (loop repeat (max 0 cycles) do
        (let ((frame-reset-applied-p nil))
          (when (plusp (apu-frame-reset-delay apu))
            (decf (apu-frame-reset-delay apu))
            (when (zerop (apu-frame-reset-delay apu))
              (%apu-apply-frame-reset! apu)
              (setf frame-reset-applied-p t)))
          (incf (apu-cycle-parity apu))
          (incf (apu-cpu-cycle-index apu))
          (let ((dmc (apu-dmc apu)))
            (when (and (apu-dmc-status-write-pending-p dmc)
                       (>= (- (apu-cpu-cycle-index apu)
                              (apu-dmc-status-write-origin-cycle dmc))
                           (if (apu-dmc-status-write-enabled-p dmc)
                               1
                             (if (= (apu-dmc-status-write-phase dmc) 1)
                                 2
                               3))))
              (setf (apu-dmc-status-write-pending-p dmc) nil
                    (apu-dmc-status-update-event dmc)
                    (if (apu-dmc-status-write-enabled-p dmc)
                        :enabled
                      (if (apu-dmc-enabled-p dmc) :implicit-disabled :disabled)))
              (unless (apu-dmc-status-write-enabled-p dmc)
                (setf (apu-dmc-bytes-remaining dmc) 0
                      (apu-dmc-load-pending-p dmc) nil))))
          (let* ((dmc (apu-dmc apu))
                 (buffer-consumed-p
                  (and (zerop (apu-dmc-timer dmc))
                       (not (apu-dmc-sample-buffer-empty-p dmc))
                       (or (zerop (apu-dmc-bits-remaining dmc))
                           (= (apu-dmc-bits-remaining dmc) 1)))))
            (%apu-clock-dmc! dmc)
            (%apu-dmc-fetch! apu buffer-consumed-p))
          (%apu-clock-triangle-timer! (apu-triangle apu))
          (when (= (apu-cycle-parity apu) 2)
            (setf (apu-cycle-parity apu) 0)
            (%apu-clock-pulse-timer! (apu-pulse-1 apu))
            (%apu-clock-pulse-timer! (apu-pulse-2 apu))
            (%apu-clock-noise-timer! (apu-noise apu)))
          (when (and (apu-frame-irq-clear-pending-p apu)
                     (zerop (apu-cycle-parity apu)))
            (setf (apu-frame-irq-pending-p apu) nil
                  (apu-frame-irq-clear-pending-p apu) nil))
          (unless frame-reset-applied-p
            (let ((irq-cycle (1+ (apu-frame-irq-cycle apu))))
              (setf (apu-frame-irq-cycle apu) irq-cycle)
              (cond
               ((and (not (apu-five-step-p apu))
                     (= irq-cycle 29829)
                     (apu-frame-irq-inhibit-p apu))
                (setf (apu-frame-irq-pending-p apu) nil
                      (apu-frame-irq-repeat-count apu) 0))
               ((and (not (apu-five-step-p apu))
                     (= irq-cycle 29828)
                     (apu-frame-irq-inhibit-p apu))
                (setf (apu-frame-irq-pending-p apu) t
                      (apu-frame-irq-repeat-count apu) 1))
               ((and (plusp (apu-frame-irq-repeat-count apu))
                     (not (apu-frame-irq-inhibit-p apu)))
                (setf (apu-frame-irq-pending-p apu) t)
                (decf (apu-frame-irq-repeat-count apu)))
               ((and (not (apu-five-step-p apu)) (= irq-cycle 29827))
                (setf (apu-frame-irq-pending-p apu) t
                      (apu-frame-irq-repeat-count apu) 2))
               (t nil))
              (when (>= irq-cycle 29830)
                (setf (apu-frame-irq-cycle apu) 0))))
          (incf (apu-frame-cycle apu))
          (if (plusp (apu-frame-tail-step apu))
              (case (apu-frame-tail-step apu)
                (1 (setf (apu-frame-tail-step apu) 2))
                (2 (setf (apu-frame-tail-step apu) 0
                         (apu-frame-step apu) 0
                         (apu-frame-cycle apu) 1))
                (3 (setf (apu-frame-tail-step apu) 0
                         (apu-frame-cycle apu) 0)))
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
                              (apu-frame-cycle apu) 0
                              (apu-frame-tail-step apu) 3)
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
                  (apu-length-halt-write-values apu) 0))))
  apu)
