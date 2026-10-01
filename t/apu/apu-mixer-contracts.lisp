(in-package #:cl-nes/test)

(describe "APU mixer contracts"
  (it "matches the NESdev reference equations for every table entry"
    (dotimes (pulse 31)
      (let ((expected (if (zerop pulse)
                          0.0f0
                          (coerce (/ 95.88d0 (+ (/ 8128d0 pulse) 100d0))
                                  'single-float))))
        (expect (<= (abs (- (aref cl-nes::+apu-pulse-mixer-table+ pulse)
                            expected))
                    1.0e-6)
                :to-be t)))
    (dotimes (tnd 203)
      (let ((expected (if (zerop tnd)
                          0.0f0
                          (coerce (/ 159.79d0
                                     (+ (/ 1d0 (/ tnd 8227d0)) 100d0))
                                  'single-float))))
        (expect (<= (abs (- (aref cl-nes::+apu-tnd-mixer-table+ tnd)
                            expected))
                    1.0e-6)
                :to-be t))))
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
        :sequence 0
        :dac-output 15)
      (seed-apu-noise-channel! noise
        :enabled-p t
        :length-counter 1
        :shift-register 0
        :constant-volume-p t
        :volume 15)
      (seed-apu-dmc-channel! dmc :output 127)
      (expect (cl-nes::%apu-triangle-output triangle) :to-be 15)
      (expect (cl-nes::%apu-noise-output noise) :to-be 15)
      (expect (apu-mix apu)
              :to-be (+ (aref cl-nes::+apu-pulse-mixer-table+ 30)
                        (aref cl-nes::+apu-tnd-mixer-table+ 202)))
      (seed-apu-triangle-channel! triangle
        :enabled-p nil
        :length-counter 0
        :linear-counter 0
        :sequence 7
        :dac-output 8)
      (seed-apu-noise-channel! noise :shift-register 1)
      (expect (cl-nes::%apu-triangle-output triangle) :to-be 8)
      (expect (cl-nes::%apu-noise-output noise) :to-be 0))))
