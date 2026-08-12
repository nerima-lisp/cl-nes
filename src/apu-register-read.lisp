(in-package #:cl-nes)

(defun apu-read-register (apu address)
  (case (logand address #xFFFF)
    (#x4015
     (let ((value (logior (if (plusp (apu-pulse-length-counter (apu-pulse-1 apu))) 1 0)
                          (if (plusp (apu-pulse-length-counter (apu-pulse-2 apu))) 2 0)
                          (if (plusp (apu-triangle-length-counter (apu-triangle apu))) 4 0)
                          (if (plusp (apu-noise-length-counter (apu-noise apu))) 8 0)
                          (if (or (plusp (apu-dmc-bytes-remaining (apu-dmc apu)))
                                  (and (plusp (apu-dmc-bits-remaining (apu-dmc apu)))
                                       (not (apu-dmc-silence-p (apu-dmc apu)))))
                              16
                              0)
                          (if (apu-frame-irq-pending-p apu) #x40 0)
                          (if (apu-dmc-irq-pending-p (apu-dmc apu)) #x80 0))))
       ;; $4015 reads acknowledge the frame IRQ latch.  The short
       ;; end-of-sequence visibility window is only for clocks before the
       ;; acknowledge; it must not recreate an IRQ after the read.
       (setf (apu-frame-irq-pending-p apu) nil
             (apu-frame-irq-repeat-count apu) 0)
       value))
    (otherwise nil)))

(defun apu-irq-pending-p (apu)
  (or (apu-frame-irq-pending-p apu)
      (apu-dmc-irq-pending-p (apu-dmc apu))))
