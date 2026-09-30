(in-package #:cl-nes/test)

(describe "Coverage: APU register contracts"
  (it "routes excluded APU reads and frame-counter writes"
    (with-fixture-apu (apu)
      (let ((bus (make-bus :apu apu)))
        (expect (bus-read bus #x4014) :to-be 0)
        (expect (bus-read bus #x4016) :to-be 0)
        (expect (bus-read bus #x4800) :to-be 0)
        (bus-write! bus #x4017 #xC0)
        (expect (cl-nes::apu-frame-irq-inhibit-p apu) :to-be t)
        (expect (cl-nes::apu-frame-last-five-step-p apu) :to-be t))))

  (it "programs pulse one sweep registers"
    (with-fixture-apu (apu pulse)
      (apu-write-register! apu #x4001 #xB6)
      (expect (cl-nes::apu-pulse-sweep-enabled-p pulse) :to-be t)
      (expect (cl-nes::apu-pulse-sweep-period pulse) :to-be 4)
      (expect (cl-nes::apu-pulse-sweep-negate-p pulse) :to-be nil)
      (expect (cl-nes::apu-pulse-sweep-shift pulse) :to-be 6)
      (expect (cl-nes::apu-pulse-sweep-reload-p pulse) :to-be t)))

  (it "reports DMC bit activity and honors frame IRQ inhibit"
    (with-fixture-apu (apu nil nil nil nil dmc)
      (setf (cl-nes::apu-dmc-bits-remaining dmc) 1
            (cl-nes::apu-dmc-bytes-remaining dmc) 0
            (cl-nes::apu-dmc-silence-p dmc) t)
      (expect (logbitp 4 (apu-read-register apu #x4015)) :to-be nil)
      (setf (cl-nes::apu-dmc-silence-p dmc) nil)
      (expect (logbitp 4 (apu-read-register apu #x4015)) :to-be t)
      (setf (cl-nes::apu-frame-irq-repeat-count apu) 1
            (cl-nes::apu-frame-irq-inhibit-p apu) t
            (cl-nes::apu-frame-irq-pending-p apu) nil)
      (apu-tick! apu 1)
      (expect (cl-nes::apu-frame-irq-repeat-count apu) :to-be 1)
      (expect (cl-nes::apu-frame-irq-pending-p apu) :to-be nil)
      (setf (cl-nes::apu-frame-irq-inhibit-p apu) nil)
      (apu-tick! apu 1)
      (expect (cl-nes::apu-frame-irq-repeat-count apu) :to-be 0)
      (expect (cl-nes::apu-frame-irq-pending-p apu) :to-be t)))

  (it "does not load a pulse length while the channel is disabled"
    (with-fixture-apu (apu pulse pulse-2)
      (apu-write-register! apu #x4003 #xA0)
      (expect (cl-nes::apu-pulse-length-counter pulse) :to-be 0)
      (apu-write-register! apu #x4015 1)
      (apu-write-register! apu #x4003 #xA0)
      (expect (cl-nes::apu-pulse-length-counter pulse) :to-be 48)
      (apu-write-register! apu #x4007 #xA0)
      (expect (cl-nes::apu-pulse-length-counter pulse-2) :to-be 0)
      (apu-write-register! apu #x4015 2)
      (apu-write-register! apu #x4007 #xA0)
      (expect (cl-nes::apu-pulse-length-counter pulse-2) :to-be 48))))
