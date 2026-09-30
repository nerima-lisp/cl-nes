(in-package #:cl-nes/test)

(describe "APU register I/O contracts"
  (it "programs pulse two, triangle, noise, and DMC registers"
    (with-fixture-apu (apu nil pulse triangle noise dmc)
      (write-apu-registers! apu
        (#x4015 #x1E)
        (#x4004 #xF3)
        (#x4005 #xBD)
        (#x4006 #x34)
        (#x4007 #xA2)
        (#x4008 #xFF)
        (#x400A #x34)
        (#x400B #xA2)
        (#x400C #xB7)
        (#x400E #x80)
        (#x400F #xA0)
        (#x4010 #xCF)
        (#x4011 #xFF)
        (#x4012 #x12)
        (#x4013 #x03))
      (expect (cl-nes::apu-pulse-duty pulse) :to-be 3)
      (expect (cl-nes::apu-pulse-timer-period pulse) :to-be #x234)
      (expect (cl-nes::apu-pulse-length-counter pulse) :to-be 48)
      (expect (cl-nes::apu-pulse-sweep-enabled-p pulse) :to-be t)
      (expect (cl-nes::apu-pulse-sweep-negate-p pulse) :to-be t)
      (expect (cl-nes::apu-triangle-timer-period triangle) :to-be #x234)
      (expect (cl-nes::apu-triangle-length-counter triangle) :to-be 48)
      (expect (cl-nes::apu-triangle-linear-reload-value triangle) :to-be #x7F)
      (expect (cl-nes::apu-noise-mode-p noise) :to-be t)
      (expect (cl-nes::apu-noise-length-counter noise) :to-be 48)
      (expect (cl-nes::apu-dmc-irq-enabled-p dmc) :to-be t)
      (expect (cl-nes::apu-dmc-loop-p dmc) :to-be t)
      (expect (cl-nes::apu-dmc-rate-index dmc) :to-be 15)
      (expect (cl-nes::apu-dmc-output dmc) :to-be #x7F)
      (expect (cl-nes::apu-dmc-sample-address dmc) :to-be #xC480)
      (expect (cl-nes::apu-dmc-sample-length dmc) :to-be 49)
      (let ((status (apu-read-register apu #x4015)))
        (expect (logand status #x1F) :to-be #x1E))
      (setf (cl-nes::apu-frame-irq-pending-p apu) t
            (cl-nes::apu-dmc-irq-pending-p dmc) t)
      (expect (apu-read-register apu #x4015) :to-be #xDE)
      (expect (cl-nes::apu-frame-irq-pending-p apu) :to-be nil)
      (expect (cl-nes::apu-dmc-irq-pending-p dmc) :to-be t)
      (apu-write-register! apu #x4010 #x4F)
      (expect (cl-nes::apu-dmc-irq-pending-p dmc) :to-be nil)))
  (it "orders a $4015 read before the same-cycle frame clock"
    (let* ((apu (make-apu))
           (bus (make-bus :apu apu)))
      (setf (cl-nes::apu-frame-step apu) 3
            (cl-nes::apu-frame-cycle apu) 22371
            (cl-nes::apu-frame-irq-inhibit-p apu) nil
            (cl-nes::apu-frame-irq-pending-p apu) nil
            (cl-nes::apu-frame-tail-step apu) 1
            (cl-nes::apu-pulse-length-counter
             (cl-nes::apu-pulse-1 apu)) 1)
      (setf (cl-nes::bus-cpu-access-hook bus)
            (lambda () (apu-tick! apu 1)))
      (expect (logand (bus-read bus #x4015) 1) :to-be 1)
      (expect (cl-nes::apu-pulse-length-counter
               (cl-nes::apu-pulse-1 apu))
              :to-be 0)
      (expect (apu-irq-pending-p apu) :to-be t))))
