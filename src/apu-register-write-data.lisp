(in-package #:cl-nes)

(defparameter +apu-register-channel-writes+
  '((#x4000 apu-pulse-1 %apu-write-pulse-control!)
    (#x4004 apu-pulse-2 %apu-write-pulse-control!)
    (#x4001 apu-pulse-1 %apu-write-pulse-sweep!)
    (#x4005 apu-pulse-2 %apu-write-pulse-sweep!)
    (#x4003 apu-pulse-1 %apu-write-pulse-timer-high!)
    (#x4007 apu-pulse-2 %apu-write-pulse-timer-high!)
    (#x4008 apu-triangle %apu-write-triangle-control!)
    (#x400B apu-triangle %apu-write-triangle-timer-high!)
    (#x400C apu-noise %apu-write-noise-control!)
    (#x400E apu-noise %apu-write-noise-period!)
    (#x400F apu-noise %apu-write-noise-length!)
    (#x4010 apu-dmc %apu-write-dmc-control!)
    (#x4015 nil %apu-write-status!)
    (#x4017 nil %apu-write-frame-counter!)))

(defparameter +apu-register-timer-low-writes+
  '((#x4002 apu-pulse-1 apu-pulse-timer-period)
    (#x4006 apu-pulse-2 apu-pulse-timer-period)
    (#x400A apu-triangle apu-triangle-timer-period)))

(defparameter +apu-register-direct-slot-writes+
  '((#x4011 apu-dmc apu-dmc-output (logand value #x7F))
    (#x4012 apu-dmc apu-dmc-sample-address (+ #xC000 (ash value 6)))
    (#x4013 apu-dmc apu-dmc-sample-length (1+ (ash value 4)))))
