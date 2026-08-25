(in-package #:cl-nes/test)

(describe "APU channel frame contracts"
  (it "uses decay envelopes and applies both pulse sweep directions"
    (with-fixture-apu (apu pulse)
      (let ((envelope (cl-nes::apu-pulse-envelope pulse)))
        (setf (cl-nes::apu-envelope-constant-volume-p envelope) nil
              (cl-nes::apu-envelope-decay envelope) 9)
        (expect (cl-nes::%apu-envelope-output envelope) :to-be 9))
      (seed-apu-pulse-channel! pulse
        :sweep-enabled-p t
        :sweep-shift 1
        :sweep-period 1
        :timer-period 16
        :sweep-negate-p t)
      (setf (cl-nes::apu-pulse-sweep-divider pulse) 0)
      (cl-nes::%apu-clock-sweep! pulse t)
      (expect (cl-nes::apu-pulse-timer-period pulse) :to-be 7)
      (seed-apu-pulse-channel! pulse
        :sweep-negate-p nil
        :timer-period 16)
      (setf (cl-nes::apu-pulse-sweep-divider pulse) 0)
      (cl-nes::%apu-clock-sweep! pulse nil)
      (expect (cl-nes::apu-pulse-timer-period pulse) :to-be 24)
      (seed-apu-pulse-channel! pulse
        :sweep-negate-p t
        :timer-period 0)
      (setf (cl-nes::apu-pulse-sweep-divider pulse) 0)
      (cl-nes::%apu-clock-sweep! pulse t)
      (expect (cl-nes::apu-pulse-timer-period pulse) :to-be 0)
      (seed-apu-pulse-channel! pulse
        :sweep-negate-p nil
        :timer-period #x7FF)
      (setf (cl-nes::apu-pulse-sweep-divider pulse) 0)
      (cl-nes::%apu-clock-sweep! pulse nil)
      (expect (cl-nes::apu-pulse-timer-period pulse) :to-be #x7FF)))

  (it "clocks triangle linear state through reload and decrement paths"
    (with-fixture-apu (apu nil nil triangle)
      (seed-apu-triangle-channel! triangle
        :linear-reload-p nil
        :linear-counter 1
        :control-p nil)
      (cl-nes::%apu-clock-quarter-frame! apu)
      (expect (cl-nes::apu-triangle-linear-counter triangle) :to-be 0)
      (expect (cl-nes::apu-triangle-linear-reload-p triangle) :to-be nil)
      (seed-apu-triangle-channel! triangle
        :linear-reload-p t
        :linear-reload-value 5
        :control-p t)
      (cl-nes::%apu-clock-quarter-frame! apu)
      (expect (cl-nes::apu-triangle-linear-counter triangle) :to-be 5)
      (expect (cl-nes::apu-triangle-linear-reload-p triangle) :to-be t)
      (seed-apu-triangle-channel! triangle :control-p nil)
      (cl-nes::%apu-clock-quarter-frame! apu)
      (expect (cl-nes::apu-triangle-linear-reload-p triangle) :to-be nil))))
