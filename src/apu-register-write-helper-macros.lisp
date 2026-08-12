(in-package #:cl-nes)

(defmacro %define-apu-envelope-control-writers ()
  `(progn
     ,@(loop for (name envelope-reader assignments)
               in '((%apu-write-pulse-control!
                     apu-pulse-envelope
                     (((apu-pulse-duty channel) (ldb (byte 2 6) value))
                      ((apu-envelope-loop-p envelope) (logbitp 5 value))
                      ((apu-envelope-constant-volume-p envelope) (logbitp 4 value))
                      ((apu-envelope-volume envelope) (logand value #x0F))))
                    (%apu-write-noise-control!
                     apu-noise-envelope
                     (((apu-envelope-loop-p envelope) (logbitp 5 value))
                      ((apu-envelope-constant-volume-p envelope) (logbitp 4 value))
                      ((apu-envelope-volume envelope) (logand value #x0F)))))
             collect
             `(defun ,name (channel value)
                (let ((envelope (,envelope-reader channel)))
                  (setf
                   ,@(loop for (place form) in assignments
                           append `(,place ,form))))))))

(defmacro %define-apu-timer-high-writers ()
  `(progn
     ,@(loop for (name enabled-reader length-reader period-reader assignments)
               in '((%apu-write-pulse-timer-high!
                     apu-pulse-enabled-p
                     apu-pulse-length-counter
                     apu-pulse-timer-period
                     (((apu-pulse-sequence channel) 0)
                      ((apu-envelope-start-p (apu-pulse-envelope channel)) t)))
                    (%apu-write-triangle-timer-high!
                     apu-triangle-enabled-p
                     apu-triangle-length-counter
                     apu-triangle-timer-period
                     (((apu-triangle-linear-reload-p channel) t)))
                    (%apu-write-noise-length!
                     apu-noise-enabled-p
                     apu-noise-length-counter
                     nil
                     (((apu-envelope-start-p (apu-noise-envelope channel)) t))))
             collect
             `(defun ,name (channel value)
                (when (,enabled-reader channel)
                  (setf (,length-reader channel) (%apu-length-value value)))
                ,@(when period-reader
                    `((setf (,period-reader channel)
                            (logior (ash (logand value 7) 8)
                                    (logand (,period-reader channel) #xFF)))))
                (setf
                 ,@(loop for (place form) in assignments
                         append `(,place ,form)))))))

(defmacro %apu-write-status-channels! (apu-var value-var)
  `(progn
     ,@(loop for (bit channel-reader enabled-reader length-reader)
               in '((0 apu-pulse-1 apu-pulse-enabled-p apu-pulse-length-counter)
                    (1 apu-pulse-2 apu-pulse-enabled-p apu-pulse-length-counter)
                    (2 apu-triangle apu-triangle-enabled-p apu-triangle-length-counter)
                    (3 apu-noise apu-noise-enabled-p apu-noise-length-counter))
             collect
             `(let* ((channel (,channel-reader ,apu-var))
                     (enabled-p (logbitp ,bit ,value-var)))
                (setf (,enabled-reader channel) enabled-p)
                (unless enabled-p
                  (setf (,length-reader channel) 0))))))
