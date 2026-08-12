(in-package #:cl-nes/test)

(describe "APU register contracts"
  (it "programs pulse two, triangle, noise, and DMC registers"
    (with-apu-channels (apu)
      (write-apu-registers apu
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
      (expect-apu-register-state
          (apu pulse-2 triangle noise dmc)
        :pulse-duty 3
        :pulse-period #x234
        :pulse-length 48
        :pulse-sweep-enabled t
        :pulse-sweep-negate t
        :triangle-period #x234
        :triangle-length 48
        :triangle-linear-reload #x7F
        :noise-mode t
        :noise-length 48
        :dmc-irq-enabled t
        :dmc-loop t
        :dmc-rate-index 15
        :dmc-output #x7F
        :dmc-sample-address #xC480
        :dmc-sample-length 49
        :status-mask #x1E)
      (setf (cl-nes::apu-frame-irq-pending-p apu) t
            (cl-nes::apu-dmc-irq-pending-p dmc) t)
      (expect (apu-read-register apu #x4015) :to-be #xDE)
      (expect (cl-nes::apu-frame-irq-pending-p apu) :to-be nil)
      (expect (cl-nes::apu-dmc-irq-pending-p dmc) :to-be t)
      (apu-write-register! apu #x4010 #x4F)
      (expect (cl-nes::apu-dmc-irq-pending-p dmc) :to-be nil)))

  (it "clears only the lengths of channels disabled by a status write"
    (with-apu-channels (apu)
      (setf (cl-nes::apu-pulse-enabled-p pulse) t
            (cl-nes::apu-pulse-length-counter pulse) 11
            (cl-nes::apu-pulse-enabled-p pulse-2) t
            (cl-nes::apu-pulse-length-counter pulse-2) 12
            (cl-nes::apu-triangle-enabled-p triangle) t
            (cl-nes::apu-triangle-length-counter triangle) 13
            (cl-nes::apu-noise-enabled-p noise) t
            (cl-nes::apu-noise-length-counter noise) 14
            (cl-nes::apu-dmc-irq-pending-p dmc) t)
      (apu-write-register! apu #x4015 #x0A)
      (expect (cl-nes::apu-pulse-enabled-p pulse) :to-be nil)
      (expect (cl-nes::apu-pulse-length-counter pulse) :to-be 0)
      (expect (cl-nes::apu-pulse-enabled-p pulse-2) :to-be t)
      (expect (cl-nes::apu-pulse-length-counter pulse-2) :to-be 12)
      (expect (cl-nes::apu-triangle-enabled-p triangle) :to-be nil)
      (expect (cl-nes::apu-triangle-length-counter triangle) :to-be 0)
      (expect (cl-nes::apu-noise-enabled-p noise) :to-be t)
      (expect (cl-nes::apu-noise-length-counter noise) :to-be 14)
      (expect (cl-nes::apu-dmc-irq-pending-p dmc) :to-be nil)))

  (it "applies output gates and mixes all channels"
    (with-apu-channels (apu)
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
