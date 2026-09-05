(in-package #:cl-nes)

(defstruct (apu-envelope
             (:constructor %make-apu-envelope))
  (loop-p nil)
  (constant-volume-p nil)
  (volume 0 :type fixnum)
  (start-p nil)
  (divider 0 :type fixnum)
  (decay 0 :type fixnum))

(defstruct (apu-pulse
             (:constructor %make-apu-pulse))
  (enabled-p nil)
  (duty 0 :type fixnum)
  (sequence 0 :type fixnum)
  (timer 0 :type fixnum)
  (timer-period 0 :type fixnum)
  (length-counter 0 :type fixnum)
  (envelope (%make-apu-envelope))
  (sweep-enabled-p nil)
  (sweep-period 0 :type fixnum)
  (sweep-negate-p nil)
  (sweep-shift 0 :type fixnum)
  (sweep-divider 0 :type fixnum)
  (sweep-reload-p nil)
  (sweep-mute-p nil))

(defstruct (apu-triangle
             (:constructor %make-apu-triangle))
  (enabled-p nil)
  (timer 0 :type fixnum)
  (timer-period 0 :type fixnum)
  (length-counter 0 :type fixnum)
  (linear-counter 0 :type fixnum)
  (linear-reload-value 0 :type fixnum)
  (linear-reload-p nil)
  (control-p nil)
  (sequence 0 :type fixnum))

(defstruct (apu-noise
             (:constructor %make-apu-noise))
  (enabled-p nil)
  (mode-p nil)
  (timer 0 :type fixnum)
  (timer-period 4 :type fixnum)
  (length-counter 0 :type fixnum)
  (shift-register #x1 :type fixnum)
  (envelope (%make-apu-envelope)))

(defstruct (apu-dmc
             (:constructor %make-apu-dmc))
  (enabled-p nil)
  (irq-enabled-p nil)
  (loop-p nil)
  (irq-pending-p nil)
  (rate-index 0 :type fixnum)
  (timer 0 :type fixnum)
  (timer-period 428 :type fixnum)
  (output 0 :type fixnum)
  (sample-address #xC000 :type fixnum)
  (current-address #xC000 :type fixnum)
  (sample-length 1 :type fixnum)
  (bytes-remaining 0 :type fixnum)
  (sample-buffer 0 :type fixnum)
  (sample-buffer-empty-p t)
  (shift-register 0 :type fixnum)
  (bits-remaining 0 :type fixnum)
  (silence-p t))

(defparameter +apu-unsupplied+ (list :apu-unsupplied))

(defun %apu-initarg-value (initargs key default)
  (getf initargs key default))

(defun %normalize-apu-initargs (initargs)
  (let ((pulse-1 (%apu-initarg-value initargs :pulse-1 +apu-unsupplied+))
        (pulse-2 (%apu-initarg-value initargs :pulse-2 +apu-unsupplied+))
        (triangle (%apu-initarg-value initargs :triangle +apu-unsupplied+))
        (noise (%apu-initarg-value initargs :noise +apu-unsupplied+))
        (dmc (%apu-initarg-value initargs :dmc +apu-unsupplied+))
        (frame-cycle (%apu-initarg-value initargs :frame-cycle 0))
        (frame-step (%apu-initarg-value initargs :frame-step 0))
        (five-step-p (%apu-initarg-value initargs :five-step-p nil))
        (frame-last-five-step-p (%apu-initarg-value initargs :frame-last-five-step-p nil))
        (frame-irq-inhibit-p (%apu-initarg-value initargs :frame-irq-inhibit-p nil))
        (frame-irq-pending-p (%apu-initarg-value initargs :frame-irq-pending-p nil))
        (frame-irq-repeat-count (%apu-initarg-value initargs :frame-irq-repeat-count 0))
        (frame-tail-step (%apu-initarg-value initargs :frame-tail-step 0))
        (frame-reset-delay (%apu-initarg-value initargs :frame-reset-delay 0))
        (frame-reset-five-step-p (%apu-initarg-value initargs :frame-reset-five-step-p nil))
        (frame-reset-irq-inhibit-p (%apu-initarg-value initargs :frame-reset-irq-inhibit-p nil))
        (cycle-parity (%apu-initarg-value initargs :cycle-parity 0))
        (memory-reader (%apu-initarg-value initargs :memory-reader nil)))
    (when (eq pulse-1 +apu-unsupplied+)
      (setf pulse-1 (%make-apu-pulse)))
    (when (eq pulse-2 +apu-unsupplied+)
      (setf pulse-2 (%make-apu-pulse)))
    (when (eq triangle +apu-unsupplied+)
      (setf triangle (%make-apu-triangle)))
    (when (eq noise +apu-unsupplied+)
      (setf noise (%make-apu-noise)))
    (when (eq dmc +apu-unsupplied+)
      (setf dmc (%make-apu-dmc)))
    (list :pulse-1 pulse-1
          :pulse-2 pulse-2
          :triangle triangle
          :noise noise
          :dmc dmc
          :frame-cycle frame-cycle
          :frame-step frame-step
          :five-step-p five-step-p
          :frame-last-five-step-p frame-last-five-step-p
          :frame-irq-inhibit-p frame-irq-inhibit-p
          :frame-irq-pending-p frame-irq-pending-p
          :frame-irq-repeat-count frame-irq-repeat-count
          :frame-tail-step frame-tail-step
          :frame-reset-delay frame-reset-delay
          :frame-reset-five-step-p frame-reset-five-step-p
          :frame-reset-irq-inhibit-p frame-reset-irq-inhibit-p
          :cycle-parity cycle-parity
          :memory-reader memory-reader)))

(defclass apu ()
  ((pulse-1 :initarg :pulse-1
            :initform nil
            :accessor apu-pulse-1)
   (pulse-2 :initarg :pulse-2
            :initform nil
            :accessor apu-pulse-2)
   (triangle :initarg :triangle
             :initform nil
             :accessor apu-triangle)
   (noise :initarg :noise
          :initform nil
          :accessor apu-noise)
   (dmc :initarg :dmc
        :initform nil
        :accessor apu-dmc)
   (frame-cycle :initarg :frame-cycle
                :initform 0
                :accessor apu-frame-cycle)
   (frame-step :initarg :frame-step
               :initform 0
               :accessor apu-frame-step)
   (five-step-p :initarg :five-step-p
                :initform nil
                :accessor apu-five-step-p)
   ;; A console RESET repeats the last mode written to $4017, while power-up
   ;; starts in four-step mode.
   (frame-last-five-step-p :initarg :frame-last-five-step-p
                           :initform nil
                           :accessor apu-frame-last-five-step-p)
   (frame-irq-inhibit-p :initarg :frame-irq-inhibit-p
                        :initform nil
                        :accessor apu-frame-irq-inhibit-p)
   (frame-irq-pending-p :initarg :frame-irq-pending-p
                        :initform nil
                        :accessor apu-frame-irq-pending-p)
   (frame-irq-repeat-count :initarg :frame-irq-repeat-count
                           :initform 0
                           :accessor apu-frame-irq-repeat-count)
   ;; Four-step mode has two clocks after its final sequencer slot.
   ;; 0 means the normal sequence is active, 1/2 are those tail clocks.
   (frame-tail-step :initarg :frame-tail-step
                    :initform 0
                    :accessor apu-frame-tail-step)
   (frame-reset-delay :initarg :frame-reset-delay
                      :initform 0
                      :accessor apu-frame-reset-delay)
   (frame-reset-five-step-p :initarg :frame-reset-five-step-p
                            :initform nil
                            :accessor apu-frame-reset-five-step-p)
   (frame-reset-irq-inhibit-p :initarg :frame-reset-irq-inhibit-p
                              :initform nil
                              :accessor apu-frame-reset-irq-inhibit-p)
   (cycle-parity :initarg :cycle-parity
                 :initform 0
                 :accessor apu-cycle-parity)
   (memory-reader :initarg :memory-reader
                  :initform nil
                  :accessor apu-memory-reader)))

(defun %make-apu (&rest initargs)
  (apply (symbol-function 'make-instance) 'apu
         (%normalize-apu-initargs initargs)))

(defun apu-p (object)
  (typep object 'apu))
