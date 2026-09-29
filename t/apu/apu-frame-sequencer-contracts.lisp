(in-package #:cl-nes/test)

(describe "APU frame sequencer contracts"
  (it "clears the frame event offset when a delayed $4017 reset applies"
    (let ((apu (make-apu)))
      (apu-write-register! apu #x4017 0)
      (expect (cl-nes::apu-frame-event-offset apu) :to-be 1)
      (apu-tick! apu 3)
      (expect (cl-nes::apu-frame-event-offset apu) :to-be 0)))

  (it "matches AccuracyCoin Test C at the four-step terminal-event boundary"
    (let ((apu (make-apu)))
      ;; An odd-cycle $4017 write takes the four-CPU-cycle reset path.
      (apu-tick! apu 1)
      (apu-write-register! apu #x4017 0)
      (apu-tick! apu 3)
      (expect (logand (apu-read-register apu #x4015) #x40) :to-be 0)
      (apu-tick! apu 1)
      (expect (logand (apu-read-register apu #x4015) #x40) :to-be 0)

      ;; The reset-application tick is frame-cycle 1; 29,827 more clocks
      ;; leave frame-cycle 29,828, before the documented terminal event.
      (apu-tick! apu 29827)
      (expect (logand (apu-read-register apu #x4015) #x40) :to-be 0)
      (apu-tick! apu 1)
      (expect (logand (apu-read-register apu #x4015) #x40) :to-be #x40)))

  (it "keeps four-step frame IRQ visible across its two tail clocks"
    (with-fixture-apu (apu)
      (seed-apu-frame-state! apu
        :frame-step 3
        :frame-irq-inhibit-p nil
        :frame-irq-pending-p nil
        :frame-irq-repeat-count 0
        :frame-tail-step 0)
      (cl-nes::%apu-frame-event! apu)
      (expect (cl-nes::apu-frame-irq-pending-p apu) :to-be t)
      (expect (cl-nes::apu-frame-irq-repeat-count apu) :to-be 2)
      (expect (cl-nes::apu-frame-tail-step apu) :to-be 1)
      (seed-apu-frame-state! apu :frame-irq-pending-p nil)
      (apu-tick! apu 1)
      (expect (cl-nes::apu-frame-irq-pending-p apu) :to-be t)
      (expect (cl-nes::apu-frame-irq-repeat-count apu) :to-be 1)
      (expect (cl-nes::apu-frame-tail-step apu) :to-be 2)
      (seed-apu-frame-state! apu :frame-irq-pending-p nil)
      (apu-tick! apu 1)
      (expect (cl-nes::apu-frame-irq-pending-p apu) :to-be t)
      (expect (cl-nes::apu-frame-irq-repeat-count apu) :to-be 0)
      (expect (cl-nes::apu-frame-tail-step apu) :to-be 0)
      (seed-apu-frame-state! apu
        :frame-step 3
        :frame-irq-inhibit-p t
        :frame-irq-pending-p nil
        :frame-tail-step 0)
      (cl-nes::%apu-frame-event! apu)
      (expect (cl-nes::apu-frame-irq-pending-p apu) :to-be nil)))

  (it "runs the five-step terminal event and restarts at cycle zero"
    (with-fixture-apu (apu)
      (seed-apu-frame-state! apu
        :five-step-p t
        :frame-step 3
        :frame-irq-pending-p nil
        :frame-tail-step 0)
      (cl-nes::%apu-frame-event! apu)
      (expect (cl-nes::apu-frame-irq-pending-p apu) :to-be nil)
      (seed-apu-frame-state! apu
        :frame-step 4
        :frame-cycle (1- (aref cl-nes::+apu-five-step-events+ 4)))
      (apu-tick! apu 1)
      (expect (cl-nes::apu-frame-step apu) :to-be 0)
      (expect (cl-nes::apu-frame-cycle apu) :to-be 0))))
