(in-package #:cl-nes)

;; 64 sub-sample phases of a 256-tap Blackman-windowed low-pass impulse.
;; Runtime audio code only indexes this immutable data and accumulates steps.
(defparameter +nes-blip-kernel-table+
  (let ((table (make-array (* 64 256) :element-type 'single-float)))
    (dotimes (phase 64 table)
      (let ((sum 0.0d0))
        (dotimes (tap 256)
          (let* ((x (- tap 127.5d0 (/ phase 64d0)))
                 (sinc (if (zerop x) 1.0d0
                           (/ (sin (* pi x)) (* pi x))))
                 (window (+ 0.42d0
                             (* 0.5d0 (cos (* pi (/ (- tap 127.5d0) 128d0))))
                             (* 0.08d0 (cos (* 2d0 pi
                                                   (/ (- tap 127.5d0) 128d0))))))
                 (coefficient (* sinc window)))
            (incf sum coefficient)
            (setf (aref table (+ (* phase 256) tap))
                  (coerce coefficient 'single-float))))
        (dotimes (tap 256)
          (setf (aref table (+ (* phase 256) tap))
                (coerce (/ (aref table (+ (* phase 256) tap)) sum)
                        'single-float)))))))
