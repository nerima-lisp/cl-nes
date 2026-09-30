(in-package #:cl-nes/test)

(describe "APU timer contracts"
  (it "clocks pulse, triangle, and noise timers"
    (with-fixture-apu (apu pulse nil triangle noise)
      (declare (ignore apu))
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
      (expect (cl-nes::apu-noise-shift-register noise) :to-be #x20))))
