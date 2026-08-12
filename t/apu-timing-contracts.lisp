(in-package #:cl-nes/test)

(describe "APU timing contracts"
  (it "clocks envelopes, lengths, sweeps, and channel timers"
    (with-apu-channels (apu)
      (let ((envelope (cl-nes::apu-pulse-envelope pulse)))
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
        (expect (cl-nes::apu-envelope-decay envelope) :to-be 14))
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
    (with-apu-channels (apu)
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
