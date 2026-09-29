(in-package #:cl-nes/test)

(defmacro seed-apu-triangle-channel!
    (triangle &key (enabled-p nil enabled-p-p)
               (timer nil timer-p)
               (period nil period-p)
               (timer-period nil timer-period-p)
               (length-counter nil length-counter-p)
               (linear-counter nil linear-counter-p)
               (linear-reload-value nil linear-reload-value-p)
               (linear-reload-p nil linear-reload-p-p)
               (control-p nil control-p-p)
               (sequence nil sequence-p))
  "Apply selected triangle-channel state in one place."
  `(setf
    ,@(%present-setf-pairs
       `(((cl-nes::apu-triangle-enabled-p ,triangle) ,enabled-p
          ,enabled-p-p)
         ((cl-nes::apu-triangle-timer ,triangle) ,timer
          ,timer-p)
         ((cl-nes::apu-triangle-timer-period ,triangle) ,period
          ,period-p)
         ((cl-nes::apu-triangle-timer-period ,triangle) ,timer-period
          ,timer-period-p)
         ((cl-nes::apu-triangle-length-counter ,triangle) ,length-counter
          ,length-counter-p)
         ((cl-nes::apu-triangle-linear-counter ,triangle) ,linear-counter
          ,linear-counter-p)
         ((cl-nes::apu-triangle-linear-reload-value ,triangle)
          ,linear-reload-value
          ,linear-reload-value-p)
         ((cl-nes::apu-triangle-linear-reload-p ,triangle)
          ,linear-reload-p
          ,linear-reload-p-p)
         ((cl-nes::apu-triangle-control-p ,triangle) ,control-p
          ,control-p-p)
         ((cl-nes::apu-triangle-sequence ,triangle) ,sequence
          ,sequence-p)))))
