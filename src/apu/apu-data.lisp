(in-package #:cl-nes)

(defparameter +apu-length-table+
  #(10 254 20  2 40  4 80  6
    160 8  60 10 14 12 26 14
    12 16 24 18 48 20 96 22
    192 24 72 26 16 28 32 30))

(defparameter +apu-noise-period-table+
  #(4 8 16 32 64 96 128 160 202 254 380 508 762 1016 2034 4068))

(defparameter +apu-dmc-rate-table+
  #(428 380 340 320 286 254 226 214
    190 160 142 128 106 84 72 54))

;; Frame-counter timestamps are expressed in CPU clocks.  The pulse/noise
;; timers run on every other CPU clock, while the frame sequencer spans a full
;; NTSC video frame in four-step mode (and five half-steps in five-step mode).
(defparameter +apu-four-step-events+ #(7458 14914 22372 29829))
(defparameter +apu-five-step-events+ #(7457 14914 22371 29829 37282))

(defparameter +apu-pulse-duty-table+
  #(#(0 1 0 0 0 0 0 0)
    #(0 1 1 0 0 0 0 0)
    #(0 1 1 1 1 0 0 0)
    #(1 0 0 1 1 1 1 1)))

(defparameter +apu-triangle-table+
  #(15 14 13 12 11 10 9 8 7 6 5 4 3 2 1 0
    0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15))

;; The mixer tables are kept with the other APU data.  Values are normalized
;; to the hardware's 0..1 output range; the formulas below are the NESdev
;; reference equations used to generate the tables.
(defparameter +apu-pulse-mixer-table+
  (coerce (loop for pulse from 0 to 30
                collect (if (zerop pulse)
                            0.0f0
                            (coerce (/ 95.88d0 (+ (/ 8128d0 pulse) 100d0))
                                    'single-float)))
          'simple-vector))

(defparameter +apu-tnd-mixer-table+
  (coerce
   (loop for tnd from 0 to 202
         collect (if (zerop tnd)
                     0.0f0
                     (coerce (/ 159.79d0
                                (+ (/ 1d0 (/ tnd 8227d0)) 100d0))
                             'single-float)))
   'simple-vector))
