(in-package #:cl-nes/test)

(describe "APU mixer contracts"
  (it "applies output gates and mixes all channels"
    (with-fixture-apu (apu pulse pulse-2 triangle noise dmc)
      (seed-apu-pulse-channel! pulse
        :enabled-p t
        :duty 3
        :sequence 0
        :timer-period 8
        :length-counter 1
        :constant-volume-p t
        :volume 15)
      (expect (cl-nes::%apu-pulse-output pulse t) :to-be 15)
      (seed-apu-pulse-channel! pulse :enabled-p nil)
      (expect (cl-nes::%apu-pulse-output pulse t) :to-be 0)
      (seed-apu-pulse-channel! pulse :enabled-p t :length-counter 0)
      (expect (cl-nes::%apu-pulse-output pulse t) :to-be 0)
      (seed-apu-pulse-channel! pulse :length-counter 1 :timer-period 7)
      (expect (cl-nes::%apu-pulse-output pulse t) :to-be 0)
      (seed-apu-pulse-channel! pulse
        :timer-period #x7FF
        :sweep-shift 1
        :sweep-negate-p nil)
      (expect (cl-nes::%apu-pulse-output pulse t) :to-be 0)
      (seed-apu-pulse-channel! pulse :sweep-shift 0 :duty 0)
      (expect (cl-nes::%apu-pulse-output pulse t) :to-be 0)
      (seed-apu-pulse-channel! pulse
        :duty 3
        :sweep-shift 0
        :timer-period 8)
      (seed-apu-pulse-channel! pulse-2
        :enabled-p t
        :duty 3
        :timer-period 8
        :length-counter 1
        :constant-volume-p t
        :volume 15)
      (seed-apu-triangle-channel! triangle
        :enabled-p t
        :length-counter 1
        :linear-counter 1
        :sequence 0)
      (seed-apu-noise-channel! noise
        :enabled-p t
        :length-counter 1
        :shift-register 0
        :constant-volume-p t
        :volume 15)
      (seed-apu-dmc-channel! dmc :output 127)
      (expect (cl-nes::%apu-triangle-output triangle) :to-be 15)
      (expect (cl-nes::%apu-noise-output noise) :to-be 15)
      (expect (apu-sample apu) :to-be 255)
      (seed-apu-triangle-channel! triangle :linear-counter 0)
      (seed-apu-noise-channel! noise :shift-register 1)
      (expect (cl-nes::%apu-triangle-output triangle) :to-be 0)
      (expect (cl-nes::%apu-noise-output noise) :to-be 0))))
