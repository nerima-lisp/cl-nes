(in-package #:cl-nes/test)

(describe "APU frame boundary contracts"
  (it "uses decay envelopes and applies both pulse sweep directions"
    (with-apu-channels (apu)
      (let ((envelope (cl-nes::apu-pulse-envelope pulse)))
        (setf (cl-nes::apu-envelope-constant-volume-p envelope) nil
              (cl-nes::apu-envelope-decay envelope) 9)
        (expect (cl-nes::%apu-envelope-output envelope) :to-be 9))
      (setf (cl-nes::apu-pulse-sweep-enabled-p pulse) t
            (cl-nes::apu-pulse-sweep-shift pulse) 1
            (cl-nes::apu-pulse-sweep-period pulse) 1
            (cl-nes::apu-pulse-sweep-divider pulse) 1
            (cl-nes::apu-pulse-sweep-negate-p pulse) t
            (cl-nes::apu-pulse-timer-period pulse) 16)
      (cl-nes::%apu-clock-sweep! pulse t)
      (expect (cl-nes::apu-pulse-timer-period pulse) :to-be 7)
      (setf (cl-nes::apu-pulse-sweep-divider pulse) 1
            (cl-nes::apu-pulse-sweep-negate-p pulse) nil
            (cl-nes::apu-pulse-timer-period pulse) 16)
      (cl-nes::%apu-clock-sweep! pulse nil)
      (expect (cl-nes::apu-pulse-timer-period pulse) :to-be 24)
      (setf (cl-nes::apu-pulse-sweep-divider pulse) 1
            (cl-nes::apu-pulse-sweep-negate-p pulse) t
            (cl-nes::apu-pulse-timer-period pulse) 0)
      (cl-nes::%apu-clock-sweep! pulse t)
      (expect (cl-nes::apu-pulse-timer-period pulse) :to-be 0)
      (setf (cl-nes::apu-pulse-sweep-divider pulse) 1
            (cl-nes::apu-pulse-sweep-negate-p pulse) nil
            (cl-nes::apu-pulse-timer-period pulse) #x7FF)
      (cl-nes::%apu-clock-sweep! pulse nil)
      (expect (cl-nes::apu-pulse-timer-period pulse) :to-be #x7FF)))

  (it "clocks triangle linear state through reload and decrement paths"
    (with-apu-channels (apu)
      (setf (cl-nes::apu-triangle-linear-reload-p triangle) nil
            (cl-nes::apu-triangle-linear-counter triangle) 1
            (cl-nes::apu-triangle-control-p triangle) nil)
      (cl-nes::%apu-clock-quarter-frame! apu)
      (expect (cl-nes::apu-triangle-linear-counter triangle) :to-be 0)
      (expect (cl-nes::apu-triangle-linear-reload-p triangle) :to-be nil)
      (setf (cl-nes::apu-triangle-linear-reload-p triangle) t
            (cl-nes::apu-triangle-linear-reload-value triangle) 5
            (cl-nes::apu-triangle-control-p triangle) t)
      (cl-nes::%apu-clock-quarter-frame! apu)
      (expect (cl-nes::apu-triangle-linear-counter triangle) :to-be 5)
      (expect (cl-nes::apu-triangle-linear-reload-p triangle) :to-be t)
      (setf (cl-nes::apu-triangle-control-p triangle) nil)
      (cl-nes::%apu-clock-quarter-frame! apu)
      (expect (cl-nes::apu-triangle-linear-reload-p triangle) :to-be nil)))

  (it "keeps four-step frame IRQ visible across its two tail clocks"
    (let ((apu (make-apu)))
      (setf (cl-nes::apu-frame-step apu) 3
            (cl-nes::apu-frame-irq-inhibit-p apu) nil
            (cl-nes::apu-frame-irq-pending-p apu) nil
            (cl-nes::apu-frame-irq-repeat-count apu) 0
            (cl-nes::apu-frame-tail-step apu) 0)
      (cl-nes::%apu-frame-event! apu)
      (expect (cl-nes::apu-frame-irq-pending-p apu) :to-be t)
      (expect (cl-nes::apu-frame-irq-repeat-count apu) :to-be 2)
      (expect (cl-nes::apu-frame-tail-step apu) :to-be 1)
      (setf (cl-nes::apu-frame-irq-pending-p apu) nil)
      (apu-tick! apu 1)
      (expect (cl-nes::apu-frame-irq-pending-p apu) :to-be t)
      (expect (cl-nes::apu-frame-irq-repeat-count apu) :to-be 1)
      (expect (cl-nes::apu-frame-tail-step apu) :to-be 2)
      (setf (cl-nes::apu-frame-irq-pending-p apu) nil)
      (apu-tick! apu 1)
      (expect (cl-nes::apu-frame-irq-pending-p apu) :to-be t)
      (expect (cl-nes::apu-frame-irq-repeat-count apu) :to-be 0)
      (expect (cl-nes::apu-frame-tail-step apu) :to-be 0)
      (setf (cl-nes::apu-frame-step apu) 3
            (cl-nes::apu-frame-irq-inhibit-p apu) t
            (cl-nes::apu-frame-irq-pending-p apu) nil
            (cl-nes::apu-frame-tail-step apu) 0)
      (cl-nes::%apu-frame-event! apu)
      (expect (cl-nes::apu-frame-irq-pending-p apu) :to-be nil)))

  (it "suppresses tail-clock IRQ reassertion while frame IRQ inhibit is active"
    (let ((apu (make-apu)))
      (setf (cl-nes::apu-frame-tail-step apu) 1
            (cl-nes::apu-frame-step apu) 3
            (cl-nes::apu-frame-irq-inhibit-p apu) t
            (cl-nes::apu-frame-irq-pending-p apu) nil
            (cl-nes::apu-frame-irq-repeat-count apu) 0)
      (apu-tick! apu 1)
      (expect (cl-nes::apu-frame-irq-pending-p apu) :to-be nil)
      (expect (cl-nes::apu-frame-tail-step apu) :to-be 2)
      (setf (cl-nes::apu-frame-irq-pending-p apu) nil)
      (apu-tick! apu 1)
      (expect (cl-nes::apu-frame-irq-pending-p apu) :to-be nil)
      (expect (cl-nes::apu-frame-tail-step apu) :to-be 0)
      (expect (cl-nes::apu-frame-step apu) :to-be 0)
      (expect (cl-nes::apu-frame-cycle apu) :to-be 1)))

  (it "enters the four-step tail sequence from the terminal timing boundary"
    (let ((apu (make-apu)))
      (setf (cl-nes::apu-five-step-p apu) nil
            (cl-nes::apu-frame-step apu) 3
            (cl-nes::apu-frame-cycle apu)
            (1- (aref cl-nes::+apu-four-step-events+ 3))
            (cl-nes::apu-cycle-parity apu) 1
            (cl-nes::apu-frame-tail-step apu) 0
            (cl-nes::apu-frame-irq-inhibit-p apu) nil
            (cl-nes::apu-frame-irq-pending-p apu) nil)
      (apu-tick! apu 1)
      (expect (cl-nes::apu-frame-tail-step apu) :to-be 1)
      (expect (cl-nes::apu-frame-step apu) :to-be 3)
      (expect (cl-nes::apu-frame-irq-pending-p apu) :to-be t)))

  (it "runs the five-step terminal event and restarts at cycle zero"
    (let ((apu (make-apu)))
      (setf (cl-nes::apu-five-step-p apu) t
            (cl-nes::apu-frame-step apu) 3
            (cl-nes::apu-frame-irq-pending-p apu) nil
            (cl-nes::apu-frame-tail-step apu) 0)
      (cl-nes::%apu-frame-event! apu)
      (expect (cl-nes::apu-frame-irq-pending-p apu) :to-be nil)
      (setf (cl-nes::apu-frame-step apu) 4
            (cl-nes::apu-frame-cycle apu)
            (1- (aref cl-nes::+apu-five-step-events+ 4)))
      (apu-tick! apu 1)
      (expect (cl-nes::apu-frame-step apu) :to-be 0)
      (expect (cl-nes::apu-frame-cycle apu) :to-be 0))))
