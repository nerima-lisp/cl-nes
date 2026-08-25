(in-package #:cl-nes/test)

(describe "APU envelope and sweep contracts"
  (it "clocks envelopes, lengths, and sweeps"
    (with-fixture-apu (apu pulse nil triangle noise)
      (declare (ignore apu))
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
            (cl-nes::apu-pulse-sweep-divider pulse) 0
            (cl-nes::apu-pulse-sweep-reload-p pulse) nil)
      (cl-nes::%apu-clock-sweep! pulse t)
      (expect (cl-nes::apu-pulse-timer-period pulse) :to-be 24)
      (setf (cl-nes::apu-pulse-timer-period pulse) 16
            (cl-nes::apu-pulse-sweep-divider pulse) 1)
      (cl-nes::%apu-clock-sweep! pulse t)
      (expect (cl-nes::apu-pulse-timer-period pulse) :to-be 16)
      (expect (cl-nes::apu-pulse-sweep-divider pulse) :to-be 0)
      (cl-nes::%apu-clock-sweep! pulse t)
      (expect (cl-nes::apu-pulse-timer-period pulse) :to-be 24)
      (expect (cl-nes::apu-pulse-sweep-divider pulse) :to-be 2)
      (setf (cl-nes::apu-pulse-sweep-reload-p pulse) t
            (cl-nes::apu-pulse-sweep-divider pulse) 0)
      (cl-nes::%apu-clock-sweep! pulse nil)
      (expect (cl-nes::apu-pulse-sweep-divider pulse) :to-be 2))))
