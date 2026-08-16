(in-package #:cl-nes/test)

(describe "APU DMC timing contracts"
  (it "clocks DMC bits and treats negative cycles as a no-op"
    (with-fixture-apu (apu nil nil nil nil dmc)
      (seed-apu-dmc-channel! dmc
        :enabled-p t
        :timer-period 1
        :timer 0
        :sample-buffer 1
        :sample-buffer-empty-p nil
        :bits-remaining 0
        :silence-p t
        :output 0)
      (apu-tick! apu 1)
      (expect (cl-nes::apu-dmc-output dmc) :to-be 2)
      (expect (cl-nes::apu-dmc-bits-remaining dmc) :to-be 7)
      (seed-apu-dmc-channel! dmc
        :timer 0
        :shift-register 0
        :bits-remaining 1
        :silence-p nil)
      (apu-tick! apu 1)
      (expect (cl-nes::apu-dmc-output dmc) :to-be 0)
      (seed-apu-dmc-channel! dmc :timer 2)
      (apu-tick! apu 1)
      (expect (cl-nes::apu-dmc-timer dmc) :to-be 1)
      (let ((frame-cycle (cl-nes::apu-frame-cycle apu)))
        (apu-tick! apu -3)
        (expect (cl-nes::apu-frame-cycle apu) :to-be frame-cycle)))))
