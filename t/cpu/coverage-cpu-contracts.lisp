(in-package #:cl-nes/test)

(describe "Coverage: CPU contracts"
  (it "delays IRQ after enabling interrupts"
    (with-fixture-cpu-system (cpu bus :program '(#x78))
      (expect (cpu-interrupt! cpu bus :reset) :to-be nil)
      (setf (cpu-p cpu) 0
            (cl-nes::cpu-irq-delay cpu) 0)
      (expect-cpu-step-cycles cpu bus 2)
      (expect (logand (cpu-p cpu) cl-nes::+flag-interrupt-disable+)
              :to-be cl-nes::+flag-interrupt-disable+)
      (expect (cl-nes::cpu-irq-delay cpu) :to-be 1))))
