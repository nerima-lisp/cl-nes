(in-package #:cl-nes)

;; Quarter/half-frame clocks and frame-counter event transitions.  The
;; cycle-level timer loop remains in APU-TIMING.LISP.

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

(defun %apu-frame-event! (apu)
  (case (apu-frame-step apu)
    (0 (%apu-clock-quarter-frame! apu))
    (1 (%apu-clock-quarter-frame! apu)
       (%apu-clock-half-frame! apu))
    (2 (%apu-clock-quarter-frame! apu))
    ;; In five-step mode this slot is the idle step.  Four-step mode sets the
    ;; frame IRQ here; its quarter/half clocks occur on the first tail clock.
    (3 (unless (apu-five-step-p apu)
         (unless (apu-frame-irq-inhibit-p apu)
           (setf (apu-frame-irq-pending-p apu) t
                 ;; The frame IRQ edge is observable for the following
                 ;; three CPU clocks.  Keep reasserting it after a status
                 ;; read during those clocks.
                 (apu-frame-irq-repeat-count apu) 2))
         (setf (apu-frame-tail-step apu) 1)))
    ;; The fifth five-step event clocks quarter/half-frame units before the
    ;; sequence starts over.
    (4 (%apu-clock-quarter-frame! apu)
       (%apu-clock-half-frame! apu)))
  apu)

(defun %apu-apply-frame-reset! (apu)
  (setf (apu-frame-cycle apu) 0
        (apu-frame-step apu) 0
        (apu-five-step-p apu) (apu-frame-reset-five-step-p apu)
        (apu-frame-irq-inhibit-p apu) (apu-frame-reset-irq-inhibit-p apu)
        (apu-frame-irq-repeat-count apu) 0
        (apu-frame-tail-step apu) 0
        (apu-frame-reset-delay apu) 0)
  (when (apu-five-step-p apu)
    (%apu-clock-quarter-frame! apu)
    (%apu-clock-half-frame! apu))
  apu)
