(in-package #:cl-nes/test)

(describe "APU register contracts"
  (it "programs pulse two, triangle, noise, and DMC registers"
    (let* ((apu (make-apu))
           (pulse (cl-nes::apu-pulse-2 apu))
           (triangle (cl-nes::apu-triangle apu))
           (noise (cl-nes::apu-noise apu))
           (dmc (cl-nes::apu-dmc apu)))
      (apu-write-register! apu #x4015 #x1E)
      (apu-write-register! apu #x4004 #xF3)
      (apu-write-register! apu #x4005 #xBD)
      (apu-write-register! apu #x4006 #x34)
      (apu-write-register! apu #x4007 #xA2)
      (apu-write-register! apu #x4008 #xFF)
      (apu-write-register! apu #x400A #x34)
      (apu-write-register! apu #x400B #xA2)
      (apu-write-register! apu #x400C #xB7)
      (apu-write-register! apu #x400E #x80)
      (apu-write-register! apu #x400F #xA0)
      (apu-write-register! apu #x4010 #xCF)
      (apu-write-register! apu #x4011 #xFF)
      (apu-write-register! apu #x4012 #x12)
      (apu-write-register! apu #x4013 #x03)
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

  (it "applies output gates and mixes all channels"
    (let* ((apu (make-apu))
           (pulse (cl-nes::apu-pulse-1 apu))
           (pulse-2 (cl-nes::apu-pulse-2 apu))
           (triangle (cl-nes::apu-triangle apu))
           (noise (cl-nes::apu-noise apu))
           (dmc (cl-nes::apu-dmc apu)))
      (setf (cl-nes::apu-pulse-enabled-p pulse) t
            (cl-nes::apu-pulse-duty pulse) 3
            (cl-nes::apu-pulse-sequence pulse) 0
            (cl-nes::apu-pulse-timer-period pulse) 8
            (cl-nes::apu-pulse-length-counter pulse) 1
            (cl-nes::apu-envelope-constant-volume-p
             (cl-nes::apu-pulse-envelope pulse)) t
            (cl-nes::apu-envelope-volume
             (cl-nes::apu-pulse-envelope pulse)) 15)
      (expect (cl-nes::%apu-pulse-output pulse t) :to-be 15)
      (setf (cl-nes::apu-pulse-enabled-p pulse) nil)
      (expect (cl-nes::%apu-pulse-output pulse t) :to-be 0)
      (setf (cl-nes::apu-pulse-enabled-p pulse) t
            (cl-nes::apu-pulse-length-counter pulse) 0)
      (expect (cl-nes::%apu-pulse-output pulse t) :to-be 0)
      (setf (cl-nes::apu-pulse-length-counter pulse) 1
            (cl-nes::apu-pulse-timer-period pulse) 7)
      (expect (cl-nes::%apu-pulse-output pulse t) :to-be 0)
      (setf (cl-nes::apu-pulse-timer-period pulse) #x7FF
            (cl-nes::apu-pulse-sweep-shift pulse) 1
            (cl-nes::apu-pulse-sweep-negate-p pulse) nil)
      (expect (cl-nes::%apu-pulse-output pulse t) :to-be 0)
      (setf (cl-nes::apu-pulse-sweep-shift pulse) 0
            (cl-nes::apu-pulse-duty pulse) 0)
      (expect (cl-nes::%apu-pulse-output pulse t) :to-be 0)
      (setf (cl-nes::apu-pulse-duty pulse) 3
            (cl-nes::apu-pulse-sweep-shift pulse) 0
            (cl-nes::apu-pulse-timer-period pulse) 8
            (cl-nes::apu-pulse-enabled-p pulse-2) t
            (cl-nes::apu-pulse-duty pulse-2) 3
            (cl-nes::apu-pulse-timer-period pulse-2) 8
            (cl-nes::apu-pulse-length-counter pulse-2) 1
            (cl-nes::apu-envelope-constant-volume-p
             (cl-nes::apu-pulse-envelope pulse-2)) t
            (cl-nes::apu-envelope-volume
             (cl-nes::apu-pulse-envelope pulse-2)) 15
            (cl-nes::apu-triangle-enabled-p triangle) t
            (cl-nes::apu-triangle-length-counter triangle) 1
            (cl-nes::apu-triangle-linear-counter triangle) 1
            (cl-nes::apu-triangle-sequence triangle) 0
            (cl-nes::apu-noise-enabled-p noise) t
            (cl-nes::apu-noise-length-counter noise) 1
            (cl-nes::apu-noise-shift-register noise) 0
            (cl-nes::apu-envelope-constant-volume-p
             (cl-nes::apu-noise-envelope noise)) t
            (cl-nes::apu-envelope-volume
             (cl-nes::apu-noise-envelope noise)) 15
            (cl-nes::apu-dmc-output dmc) 127)
      (expect (cl-nes::%apu-triangle-output triangle) :to-be 15)
      (expect (cl-nes::%apu-noise-output noise) :to-be 15)
      (expect (apu-sample apu) :to-be 255)
      (setf (cl-nes::apu-triangle-linear-counter triangle) 0
            (cl-nes::apu-noise-shift-register noise) 1)
      (expect (cl-nes::%apu-triangle-output triangle) :to-be 0)
      (expect (cl-nes::%apu-noise-output noise) :to-be 0))))

(describe "APU timing contracts"
  (it "clocks envelopes, lengths, sweeps, and channel timers"
    (let* ((apu (make-apu))
           (pulse (cl-nes::apu-pulse-1 apu))
           (envelope (cl-nes::apu-pulse-envelope pulse))
           (triangle (cl-nes::apu-triangle apu))
           (noise (cl-nes::apu-noise apu)))
      (setf (cl-nes::apu-envelope-volume envelope) 2
            (cl-nes::apu-envelope-start-p envelope) t)
      (cl-nes::%apu-clock-envelope! envelope)
      (expect (cl-nes::apu-envelope-decay envelope) :to-be 15)
      (expect (cl-nes::apu-envelope-divider envelope) :to-be 2)
      (cl-nes::%apu-clock-envelope! envelope)
      (cl-nes::%apu-clock-envelope! envelope)
      (cl-nes::%apu-clock-envelope! envelope)
      (expect (cl-nes::apu-envelope-decay envelope) :to-be 14)
      (setf (cl-nes::apu-envelope-decay envelope) 0
            (cl-nes::apu-envelope-divider envelope) 0
            (cl-nes::apu-envelope-loop-p envelope) t)
      (cl-nes::%apu-clock-envelope! envelope)
      (expect (cl-nes::apu-envelope-decay envelope) :to-be 15)
      (setf (cl-nes::apu-envelope-loop-p envelope) nil
            (cl-nes::apu-envelope-divider envelope) 0)
      (cl-nes::%apu-clock-envelope! envelope)
      (expect (cl-nes::apu-envelope-decay envelope) :to-be 14)
      (setf (cl-nes::apu-pulse-length-counter pulse) 1)
      (cl-nes::%apu-clock-length! pulse nil)
      (expect (cl-nes::apu-pulse-length-counter pulse) :to-be 0)
      (setf (cl-nes::apu-pulse-length-counter pulse) 1)
      (cl-nes::%apu-clock-length! pulse t)
      (expect (cl-nes::apu-pulse-length-counter pulse) :to-be 1)
      (setf (cl-nes::apu-triangle-length-counter triangle) 1)
      (cl-nes::%apu-clock-length! triangle nil)
      (expect (cl-nes::apu-triangle-length-counter triangle) :to-be 0)
      (setf (cl-nes::apu-noise-length-counter noise) 1)
      (cl-nes::%apu-clock-length! noise nil)
      (expect (cl-nes::apu-noise-length-counter noise) :to-be 0)
      (expect (cl-nes::%apu-clock-length! nil nil) :to-be nil)
      (setf (cl-nes::apu-pulse-timer-period pulse) 16
            (cl-nes::apu-pulse-sweep-enabled-p pulse) t
            (cl-nes::apu-pulse-sweep-shift pulse) 1
            (cl-nes::apu-pulse-sweep-period pulse) 2
            (cl-nes::apu-pulse-sweep-divider pulse) 1
            (cl-nes::apu-pulse-sweep-reload-p pulse) nil)
      (cl-nes::%apu-clock-sweep! pulse t)
      (expect (cl-nes::apu-pulse-timer-period pulse) :to-be 24)
      (setf (cl-nes::apu-pulse-sweep-reload-p pulse) t
            (cl-nes::apu-pulse-sweep-divider pulse) 0)
      (cl-nes::%apu-clock-sweep! pulse nil)
      (expect (cl-nes::apu-pulse-sweep-divider pulse) :to-be 2)
      (setf (cl-nes::apu-pulse-timer pulse) 0
            (cl-nes::apu-pulse-timer-period pulse) 2
            (cl-nes::apu-pulse-sequence pulse) 7)
      (cl-nes::%apu-clock-pulse-timer! pulse)
      (expect (cl-nes::apu-pulse-sequence pulse) :to-be 0)
      (setf (cl-nes::apu-pulse-timer pulse) 1)
      (cl-nes::%apu-clock-pulse-timer! pulse)
      (expect (cl-nes::apu-pulse-timer pulse) :to-be 0)
      (setf (cl-nes::apu-triangle-timer triangle) 0
            (cl-nes::apu-triangle-timer-period triangle) 2
            (cl-nes::apu-triangle-length-counter triangle) 1
            (cl-nes::apu-triangle-linear-counter triangle) 1
            (cl-nes::apu-triangle-sequence triangle) 31)
      (cl-nes::%apu-clock-triangle-timer! triangle)
      (expect (cl-nes::apu-triangle-sequence triangle) :to-be 0)
      (setf (cl-nes::apu-triangle-timer triangle) 1)
      (cl-nes::%apu-clock-triangle-timer! triangle)
      (expect (cl-nes::apu-triangle-timer triangle) :to-be 0)
      (setf (cl-nes::apu-noise-timer noise) 0
            (cl-nes::apu-noise-timer-period noise) 2
            (cl-nes::apu-noise-shift-register noise) #x41
            (cl-nes::apu-noise-mode-p noise) nil)
      (cl-nes::%apu-clock-noise-timer! noise)
      (expect (cl-nes::apu-noise-shift-register noise) :to-be #x4020)
      (setf (cl-nes::apu-noise-timer noise) 0
            (cl-nes::apu-noise-shift-register noise) #x41
            (cl-nes::apu-noise-mode-p noise) t)
      (cl-nes::%apu-clock-noise-timer! noise)
      (expect (cl-nes::apu-noise-shift-register noise) :to-be #x20)))

  (it "clocks DMC bits and treats negative cycles as a no-op"
    (let* ((apu (make-apu))
           (dmc (cl-nes::apu-dmc apu)))
      (setf (cl-nes::apu-dmc-enabled-p dmc) t
            (cl-nes::apu-dmc-timer-period dmc) 1
            (cl-nes::apu-dmc-timer dmc) 0
            (cl-nes::apu-dmc-sample-buffer dmc) 1
            (cl-nes::apu-dmc-sample-buffer-empty-p dmc) nil
            (cl-nes::apu-dmc-bits-remaining dmc) 0
            (cl-nes::apu-dmc-silence-p dmc) t
            (cl-nes::apu-dmc-output dmc) 0)
      (apu-tick! apu 1)
      (expect (cl-nes::apu-dmc-output dmc) :to-be 2)
      (expect (cl-nes::apu-dmc-bits-remaining dmc) :to-be 7)
      (setf (cl-nes::apu-dmc-timer dmc) 0
            (cl-nes::apu-dmc-shift-register dmc) 0
            (cl-nes::apu-dmc-bits-remaining dmc) 1
            (cl-nes::apu-dmc-silence-p dmc) nil)
      (apu-tick! apu 1)
      (expect (cl-nes::apu-dmc-output dmc) :to-be 0)
      (setf (cl-nes::apu-dmc-timer dmc) 2)
      (apu-tick! apu 1)
      (expect (cl-nes::apu-dmc-timer dmc) :to-be 1)
      (let ((frame-cycle (cl-nes::apu-frame-cycle apu)))
        (apu-tick! apu -3)
        (expect (cl-nes::apu-frame-cycle apu) :to-be frame-cycle)))))

(describe "APU frame boundary contracts"
  (it "uses decay envelopes and applies both pulse sweep directions"
    (let* ((apu (make-apu))
           (pulse (cl-nes::apu-pulse-1 apu))
           (envelope (cl-nes::apu-pulse-envelope pulse)))
      (setf (cl-nes::apu-envelope-constant-volume-p envelope) nil
            (cl-nes::apu-envelope-decay envelope) 9)
      (expect (cl-nes::%apu-envelope-output envelope) :to-be 9)
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
    (let* ((apu (make-apu))
           (triangle (cl-nes::apu-triangle apu)))
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
