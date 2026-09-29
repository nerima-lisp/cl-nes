(in-package #:cl-nes/test)

(defmacro seed-apu-noise-channel!
    (noise &key (enabled-p nil enabled-p-p)
            (timer nil timer-p)
            (period nil period-p)
            (timer-period nil timer-period-p)
            (length-counter nil length-counter-p)
            (shift-register nil shift-register-p)
            (mode-p nil mode-p-p)
            (constant-volume-p nil constant-volume-p-p)
            (volume nil volume-p))
  "Apply selected noise-channel state in one place."
  `(setf
    ,@(%present-setf-pairs
       `(((cl-nes::apu-noise-enabled-p ,noise) ,enabled-p
          ,enabled-p-p)
         ((cl-nes::apu-noise-timer ,noise) ,timer
          ,timer-p)
         ((cl-nes::apu-noise-timer-period ,noise) ,period
          ,period-p)
         ((cl-nes::apu-noise-timer-period ,noise) ,timer-period
          ,timer-period-p)
         ((cl-nes::apu-noise-length-counter ,noise) ,length-counter
          ,length-counter-p)
         ((cl-nes::apu-noise-shift-register ,noise) ,shift-register
          ,shift-register-p)
         ((cl-nes::apu-noise-mode-p ,noise) ,mode-p
          ,mode-p-p)
         ((cl-nes::apu-envelope-constant-volume-p
           (cl-nes::apu-noise-envelope ,noise))
          ,constant-volume-p
          ,constant-volume-p-p)
         ((cl-nes::apu-envelope-volume
           (cl-nes::apu-noise-envelope ,noise))
          ,volume
          ,volume-p)))))
