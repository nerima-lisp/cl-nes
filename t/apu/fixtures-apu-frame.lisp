(in-package #:cl-nes/test)

(defmacro seed-apu-frame-state!
    (apu &key (five-step-p nil five-step-p-p)
         (frame-step nil frame-step-p)
         (frame-cycle nil frame-cycle-p)
         (frame-irq-inhibit-p nil frame-irq-inhibit-p-p)
         (frame-irq-pending-p nil frame-irq-pending-p-p)
         (frame-irq-repeat-count nil frame-irq-repeat-count-p)
         (frame-tail-step nil frame-tail-step-p))
  "Apply selected frame-sequencer state in one place."
  `(setf
    ,@(%present-setf-pairs
       `(((cl-nes::apu-five-step-p ,apu) ,five-step-p
          ,five-step-p-p)
         ((cl-nes::apu-frame-step ,apu) ,frame-step
          ,frame-step-p)
         ((cl-nes::apu-frame-cycle ,apu) ,frame-cycle
          ,frame-cycle-p)
         ((cl-nes::apu-frame-irq-inhibit-p ,apu) ,frame-irq-inhibit-p
          ,frame-irq-inhibit-p-p)
         ((cl-nes::apu-frame-irq-pending-p ,apu) ,frame-irq-pending-p
          ,frame-irq-pending-p-p)
         ((cl-nes::apu-frame-irq-repeat-count ,apu)
          ,frame-irq-repeat-count
          ,frame-irq-repeat-count-p)
         ((cl-nes::apu-frame-tail-step ,apu) ,frame-tail-step
          ,frame-tail-step-p)))))
