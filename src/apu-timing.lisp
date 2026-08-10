(in-package #:cl-nes)

;; Per-cycle APU state transitions live here.  Register decoding remains in
;; APU-REGISTERS.LISP, while hardware tables and state records stay in their
;; dedicated source files.

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
               (plusp divider))
      (let ((target (%apu-pulse-sweep-target pulse first-p)))
        (when (and (<= 0 target) (<= target #x7FF))
          (setf (apu-pulse-timer-period pulse) target))))
    (if (or reload (zerop divider))
        (setf (apu-pulse-sweep-divider pulse)
              (apu-pulse-sweep-period pulse))
        (decf (apu-pulse-sweep-divider pulse)))
    (when reload
      (setf (apu-pulse-sweep-reload-p pulse) nil))))

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

(defun %apu-dmc-restart! (dmc)
  ;; $4015 reloads the DMA address and length.  It does not discard a byte
  ;; that has already been prefetched, nor does it reset the output unit.
  (setf (apu-dmc-current-address dmc) (apu-dmc-sample-address dmc)
        (apu-dmc-bytes-remaining dmc) (apu-dmc-sample-length dmc)))

(defun %apu-dmc-advance-address! (dmc)
  ;; The DMC wraps from $FFFF to $8000, unlike the sample start address
  ;; register which is restricted to $C000-$FFFF.
  (setf (apu-dmc-current-address dmc)
        (if (= (apu-dmc-current-address dmc) #xFFFF)
            #x8000
            (1+ (apu-dmc-current-address dmc)))))

(defun %apu-dmc-fetch! (apu)
  (let ((dmc (apu-dmc apu)))
    (when (and (apu-dmc-enabled-p dmc)
               (apu-dmc-sample-buffer-empty-p dmc)
               (plusp (apu-dmc-bytes-remaining dmc)))
      (let ((reader (apu-memory-reader apu)))
        ;; APUs created through MAKE-APU do not necessarily belong to a bus.
        ;; A missing reader still consumes the byte as zero, so a malformed
        ;; standalone setup cannot leave the DMC active forever.
        (setf (apu-dmc-sample-buffer dmc)
              (logand (or (and reader
                                (funcall reader (apu-dmc-current-address dmc)))
                          0)
                      #xFF)
              (apu-dmc-sample-buffer-empty-p dmc) nil)
        (%apu-dmc-advance-address! dmc)
        (decf (apu-dmc-bytes-remaining dmc))
        (if (zerop (apu-dmc-bytes-remaining dmc))
            (if (apu-dmc-loop-p dmc)
                (setf (apu-dmc-current-address dmc) (apu-dmc-sample-address dmc)
                      (apu-dmc-bytes-remaining dmc) (apu-dmc-sample-length dmc))
                (when (apu-dmc-irq-enabled-p dmc)
                  (setf (apu-dmc-irq-pending-p dmc) t))))))))

(defun %apu-clock-dmc! (dmc)
  (if (zerop (apu-dmc-timer dmc))
      (progn
        ;; The reload cycle itself emits a bit.  Store period-1 so the
        ;; countdown produces exactly the table's number of CPU clocks
        ;; between output bits.
        (setf (apu-dmc-timer dmc)
              (1- (apu-dmc-timer-period dmc)))
        (when (zerop (apu-dmc-bits-remaining dmc))
          (if (apu-dmc-sample-buffer-empty-p dmc)
              (setf (apu-dmc-silence-p dmc) t)
              (setf (apu-dmc-shift-register dmc)
                    (apu-dmc-sample-buffer dmc)
                    (apu-dmc-sample-buffer-empty-p dmc) t
                    (apu-dmc-bits-remaining dmc) 8
                    (apu-dmc-silence-p dmc) nil)))
        (unless (apu-dmc-silence-p dmc)
          (when (logbitp 0 (apu-dmc-shift-register dmc))
            (setf (apu-dmc-output dmc)
                  (min 127 (+ 2 (apu-dmc-output dmc)))))
          (unless (logbitp 0 (apu-dmc-shift-register dmc))
            (setf (apu-dmc-output dmc)
                  (max 0 (- (apu-dmc-output dmc) 2))))
          (setf (apu-dmc-shift-register dmc)
                (ash (apu-dmc-shift-register dmc) -1))
          (decf (apu-dmc-bits-remaining dmc))))
      (decf (apu-dmc-timer dmc))))

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
    (%apu-dmc-fetch! apu)
    (%apu-clock-dmc! (apu-dmc apu))
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
            ;; In four-step mode the second slot is half a CPU clock wide in
            ;; the reference timing.  A boundary reached on the even APU
            ;; phase is already observable at the preceding integer cycle;
            ;; the odd phase is not observable until the following cycle.
            (when (or (>= (apu-frame-cycle apu) event-cycle)
                      (and (not (apu-five-step-p apu))
                           (= step 1)
                           (= (apu-frame-cycle apu) (1- event-cycle))
                           (zerop (apu-cycle-parity apu))))
              (%apu-frame-event! apu)
              (when (= step (1- (length events)))
                (if (apu-five-step-p apu)
                    (setf (apu-frame-step apu) 0
                          (apu-frame-cycle apu) 0)
                    ;; Four-step mode continues through FRAME-TAIL-STEP.
                    nil))
              (unless (= step (1- (length events)))
                (incf (apu-frame-step apu))))))))
  apu)
