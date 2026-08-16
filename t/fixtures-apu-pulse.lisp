(in-package #:cl-nes/test)

(defmacro seed-apu-pulse-channel!
    (pulse &key (enabled-p nil enabled-p-p)
           (duty nil duty-p)
           (sequence nil sequence-p)
           (timer nil timer-p)
           (period nil period-p)
           (timer-period nil timer-period-p)
           (length-counter nil length-counter-p)
           (sweep-enabled-p nil sweep-enabled-p-p)
           (sweep-period nil sweep-period-p)
           (sweep-shift nil sweep-shift-p)
           (sweep-negate-p nil sweep-negate-p-p)
           (constant-volume-p nil constant-volume-p-p)
           (volume nil volume-p))
  "Apply selected pulse-channel state in one place."
  `(setf
    ,@(%present-setf-pairs
       `(((cl-nes::apu-pulse-enabled-p ,pulse) ,enabled-p
          ,enabled-p-p)
         ((cl-nes::apu-pulse-duty ,pulse) ,duty
          ,duty-p)
         ((cl-nes::apu-pulse-sequence ,pulse) ,sequence
          ,sequence-p)
         ((cl-nes::apu-pulse-timer ,pulse) ,timer
          ,timer-p)
         ((cl-nes::apu-pulse-timer-period ,pulse) ,period
          ,period-p)
         ((cl-nes::apu-pulse-timer-period ,pulse) ,timer-period
          ,timer-period-p)
         ((cl-nes::apu-pulse-length-counter ,pulse) ,length-counter
          ,length-counter-p)
         ((cl-nes::apu-pulse-sweep-enabled-p ,pulse) ,sweep-enabled-p
          ,sweep-enabled-p-p)
         ((cl-nes::apu-pulse-sweep-period ,pulse) ,sweep-period
          ,sweep-period-p)
         ((cl-nes::apu-pulse-sweep-shift ,pulse) ,sweep-shift
          ,sweep-shift-p)
         ((cl-nes::apu-pulse-sweep-negate-p ,pulse) ,sweep-negate-p
          ,sweep-negate-p-p)
         ((cl-nes::apu-envelope-constant-volume-p
           (cl-nes::apu-pulse-envelope ,pulse))
          ,constant-volume-p
          ,constant-volume-p-p)
         ((cl-nes::apu-envelope-volume
           (cl-nes::apu-pulse-envelope ,pulse))
          ,volume
          ,volume-p)))))
