(in-package #:cl-nes/test)

(defmacro seed-apu-dmc-channel!
    (dmc &key (enabled-p nil enabled-p-p)
          (irq-enabled-p nil irq-enabled-p-p)
          (irq-pending-p nil irq-pending-p-p)
          (loop-p nil loop-p-p)
          (rate-index nil rate-index-p)
          (timer nil timer-p)
          (period nil period-p)
          (timer-period nil timer-period-p)
          (sample-buffer nil sample-buffer-p)
          (sample-buffer-empty-p nil sample-buffer-empty-p-p)
          (bits-remaining nil bits-remaining-p)
          (silence-p nil silence-p-p)
          (output nil output-p)
          (shift-register nil shift-register-p)
          (sample-address nil sample-address-p)
          (sample-length nil sample-length-p))
  "Apply selected DMC state in one place."
  `(setf
    ,@(%present-setf-pairs
       `(((cl-nes::apu-dmc-enabled-p ,dmc) ,enabled-p
          ,enabled-p-p)
         ((cl-nes::apu-dmc-irq-enabled-p ,dmc) ,irq-enabled-p
          ,irq-enabled-p-p)
         ((cl-nes::apu-dmc-irq-pending-p ,dmc) ,irq-pending-p
          ,irq-pending-p-p)
         ((cl-nes::apu-dmc-loop-p ,dmc) ,loop-p
          ,loop-p-p)
         ((cl-nes::apu-dmc-rate-index ,dmc) ,rate-index
          ,rate-index-p)
         ((cl-nes::apu-dmc-timer ,dmc) ,timer
          ,timer-p)
         ((cl-nes::apu-dmc-timer-period ,dmc) ,period
          ,period-p)
         ((cl-nes::apu-dmc-timer-period ,dmc) ,timer-period
          ,timer-period-p)
         ((cl-nes::apu-dmc-sample-buffer ,dmc) ,sample-buffer
          ,sample-buffer-p)
         ((cl-nes::apu-dmc-sample-buffer-empty-p ,dmc)
          ,sample-buffer-empty-p
          ,sample-buffer-empty-p-p)
         ((cl-nes::apu-dmc-bits-remaining ,dmc) ,bits-remaining
          ,bits-remaining-p)
         ((cl-nes::apu-dmc-silence-p ,dmc) ,silence-p
          ,silence-p-p)
         ((cl-nes::apu-dmc-output ,dmc) ,output
          ,output-p)
         ((cl-nes::apu-dmc-shift-register ,dmc) ,shift-register
          ,shift-register-p)
         ((cl-nes::apu-dmc-sample-address ,dmc) ,sample-address
          ,sample-address-p)
         ((cl-nes::apu-dmc-sample-length ,dmc) ,sample-length
          ,sample-length-p)))))
