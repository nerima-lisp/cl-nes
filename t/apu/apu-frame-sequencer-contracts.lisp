(in-package #:cl-nes/test)

(describe "APU frame sequencer contracts"
  (it "preserves the mode-0 parity marker through the terminal IRQ"
    (let ((apu (make-apu)))
      (apu-write-register! apu #x4017 0)
      (apu-tick! apu 5)
      (expect (cl-nes::apu-frame-event-offset apu) :to-be 1)
      (apu-tick! apu 29827)
      (expect (cl-nes::apu-frame-event-offset apu) :to-be 0)
      (expect (cl-nes::apu-frame-irq-pending-p apu) :to-be t))
    (let* ((apu (make-apu))
           (bus (make-bus :apu apu)))
      (setf (cl-nes::apu-frame-step apu) 3
            (cl-nes::apu-frame-cycle apu) (1- (aref cl-nes::+apu-four-step-events+ 3))
            (cl-nes::apu-frame-event-offset apu) 1
            (cl-nes::bus-cpu-access-hook bus) (lambda () (apu-tick! apu 1)))
      (expect (logand (bus-read bus #x4015) #x40) :to-be #x40)
      (expect (cl-nes::apu-frame-irq-pending-p apu) :to-be t))
    (let* ((apu (make-apu))
           (bus (make-bus :apu apu)))
      (setf (cl-nes::apu-frame-step apu) 3
            (cl-nes::apu-frame-cycle apu) (1- (aref cl-nes::+apu-four-step-events+ 3))
            (cl-nes::bus-cpu-access-hook bus) (lambda () (apu-tick! apu 1)))
      (expect (logand (bus-read bus #x4015) #x40) :to-be 0)
      (expect (cl-nes::apu-frame-irq-pending-p apu) :to-be t)))

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

  (it "reasserts a four-step frame IRQ only in the first tail clock"
    (with-fixture-apu (apu pulse)
      (setf (cl-nes::apu-pulse-length-counter pulse) 2)
      (seed-apu-frame-state! apu
        :frame-step 3
        :frame-irq-inhibit-p nil
        :frame-irq-pending-p nil
        :frame-irq-repeat-count 0
        :frame-tail-step 0)
      (cl-nes::%apu-frame-event! apu)
      (expect (cl-nes::apu-frame-irq-pending-p apu) :to-be t)
      (expect (cl-nes::apu-frame-irq-repeat-count apu) :to-be 1)
      (expect (cl-nes::apu-frame-tail-step apu) :to-be 1)
      (expect (cl-nes::apu-pulse-length-counter pulse) :to-be 1)
      (expect (logand (apu-read-register apu #x4015) #x40) :to-be #x40)
      (expect (cl-nes::apu-frame-irq-pending-p apu) :to-be nil)
      (apu-tick! apu 1)
      (expect (cl-nes::apu-frame-irq-pending-p apu) :to-be t)
      (expect (cl-nes::apu-frame-irq-repeat-count apu) :to-be 0)
      (expect (cl-nes::apu-frame-tail-step apu) :to-be 2)
      (expect (cl-nes::apu-pulse-length-counter pulse) :to-be 1)
      (expect (logand (apu-read-register apu #x4015) #x40) :to-be #x40)
      (expect (cl-nes::apu-frame-irq-pending-p apu) :to-be nil)
      (apu-tick! apu 1)
      (expect (cl-nes::apu-frame-irq-pending-p apu) :to-be nil)
      (expect (cl-nes::apu-frame-irq-repeat-count apu) :to-be 0)
      (expect (cl-nes::apu-frame-tail-step apu) :to-be 0)
      (seed-apu-frame-state! apu
        :frame-step 3
        :frame-irq-inhibit-p t
        :frame-irq-pending-p nil
        :frame-tail-step 0)
      (cl-nes::%apu-frame-event! apu)
      (expect (cl-nes::apu-frame-irq-pending-p apu) :to-be nil)))

  (it "defers the next mode-1 length clock by one APU cycle"
    (with-fixture-apu (apu pulse)
      (setf (cl-nes::apu-pulse-enabled-p pulse) t
            (cl-nes::apu-pulse-length-counter pulse) 2
            (cl-nes::apu-envelope-loop-p
             (cl-nes::apu-pulse-envelope pulse))
            nil)
      (seed-apu-frame-state! apu
        :five-step-p t
        :frame-step 3
        :frame-irq-pending-p nil
        :frame-tail-step 0)
      (cl-nes::%apu-frame-event! apu)
      (expect (cl-nes::apu-frame-irq-pending-p apu) :to-be nil)
      (seed-apu-frame-state! apu
        :frame-step 4
        :frame-cycle (1- (aref cl-nes::+apu-five-step-events+ 4))
        :frame-tail-step 0)
      (apu-tick! apu 1)
      (expect (cl-nes::apu-pulse-length-counter pulse) :to-be 1)
      (expect (cl-nes::apu-frame-tail-step apu) :to-be 3)
      (apu-tick! apu 1)
      (expect (cl-nes::apu-frame-cycle apu) :to-be 0)
      (expect (cl-nes::apu-frame-tail-step apu) :to-be 0)
      (apu-tick! apu 14912)
      (expect (cl-nes::apu-frame-cycle apu) :to-be 14912)
      (expect (cl-nes::apu-pulse-length-counter pulse) :to-be 1)
      (apu-tick! apu 1)
      (expect (cl-nes::apu-pulse-length-counter pulse) :to-be 0))))

(describe "APU frame reset parity contracts"
  (it "counts the reset tick after four post-write cycles on parity zero"
    (let* ((apu (make-apu))
           (bus (make-bus :apu apu)))
      (setf (cl-nes::bus-cpu-access-hook bus)
            (lambda () (apu-tick! apu 1)))
      (bus-write! bus #x4017 0)
      (expect (cl-nes::apu-frame-reset-delay apu) :to-be 4)
      (apu-tick! apu 3)
      (expect (cl-nes::apu-frame-reset-delay apu) :to-be 1)
      (apu-tick! apu 1)
      (expect (cl-nes::apu-frame-reset-delay apu) :to-be 0)
      (expect (cl-nes::apu-frame-cycle apu) :to-be 2)))

  (it "counts the reset application tick after the parity-one delay"
    (let* ((apu (make-apu))
           (bus (make-bus :apu apu)))
      (setf (cl-nes::bus-cpu-access-hook bus)
            (lambda () (apu-tick! apu 1)))
      (apu-tick! apu 1)
      (progn
        (expect (cl-nes::apu-cycle-parity apu) :to-be 1)
        (bus-write! bus #x4017 0))
      (expect (cl-nes::apu-frame-reset-delay apu) :to-be 3)
      (apu-tick! apu 2)
      (expect (cl-nes::apu-frame-reset-delay apu) :to-be 1)
      (expect (cl-nes::apu-frame-cycle apu) :to-be 4)
      (apu-tick! apu 1)
      (expect (cl-nes::apu-frame-reset-delay apu) :to-be 0)
      (expect (cl-nes::apu-frame-cycle apu) :to-be 1)))

  (it "exposes the due five-step length clock to a $4015 read"
    (let* ((apu (make-apu))
           (bus (make-bus :apu apu)))
      (apu-write-register! apu #x4015 1)
      (apu-write-register! apu #x4003 #x18)
      (setf (cl-nes::bus-cpu-access-hook bus)
            (lambda () (apu-tick! apu 1)))
      (bus-write! bus #x4017 #x80)
      (apu-tick! apu 3)
      (expect (cl-nes::apu-pulse-length-counter (cl-nes::apu-pulse-1 apu)) :to-be 2)
      (expect (cl-nes::apu-frame-reset-delay apu) :to-be 1)
      (bus-write! bus #x4017 #x80)
      (expect (cl-nes::apu-pulse-length-counter (cl-nes::apu-pulse-1 apu)) :to-be 1)
      (expect (cl-nes::apu-frame-reset-delay apu) :to-be 4)
      (apu-tick! apu 3)
      (expect (cl-nes::apu-pulse-length-counter (cl-nes::apu-pulse-1 apu)) :to-be 1)
      (expect (cl-nes::apu-frame-reset-delay apu) :to-be 1)
      (expect (logand (bus-read bus #x4015) 1) :to-be 0)
      (expect (cl-nes::apu-pulse-length-counter (cl-nes::apu-pulse-1 apu)) :to-be 0)
      (expect (cl-nes::apu-frame-reset-delay apu) :to-be 0))))
