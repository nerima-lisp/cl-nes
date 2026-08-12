(in-package #:cl-nes)

(defmacro %apu-register-write-dispatch (apu-var address-var)
  `(case (logand ,address-var #xFFFF)
     ,@(loop for (address channel-reader writer)
               in +apu-register-channel-writes+
             collect
             `((,address)
               ,(if channel-reader
                    `(,writer (,channel-reader ,apu-var) value)
                    `(,writer ,apu-var value))))
     ,@(loop for (address channel-reader period-reader)
               in +apu-register-timer-low-writes+
             collect
             `((,address)
               (let ((channel (,channel-reader ,apu-var)))
                 (setf (,period-reader channel)
                       (%apu-merge-timer-low (,period-reader channel)
                                             value)))))
     ,@(loop for (address channel-reader slot-reader value-form)
               in +apu-register-direct-slot-writes+
             collect
             `((,address)
               (let ((channel (,channel-reader ,apu-var)))
                 (setf (,slot-reader channel) ,value-form))))))
