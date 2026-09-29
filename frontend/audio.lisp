(in-package #:cl-nes/frontend)

(defstruct (audio-queue (:constructor %make-audio-queue (sample-rate)))
  sample-rate device opened-p (queued-bytes 0))

(defun make-audio-queue (&key (sample-rate cl-nes:+nes-default-audio-sample-rate+)
                              (capacity 8192))
  (declare (ignore capacity))
  (%make-audio-queue sample-rate))

#+sbcl
(progn
  (defconstant +sdl-init-audio+ #x00000010)
  (defconstant +sdl-audio-allow-frequency-change+ #x00000001)
  (defconstant +sdl-audio-s16lsb+ #x8010)
  (sb-alien:define-alien-routine ("SDL_InitSubSystem" %sdl-init) sb-alien:int
    (flags sb-alien:unsigned-int))
  (sb-alien:define-alien-routine ("SDL_QuitSubSystem" %sdl-quit) sb-alien:void
    (flags sb-alien:unsigned-int))
  (sb-alien:define-alien-routine ("SDL_OpenAudioDevice" %sdl-open-audio) sb-alien:unsigned-int
    (name (* sb-alien:char)) (iscapture sb-alien:int) (spec (* t))
    (obtained (* t)) (allowed-changes sb-alien:int))
  (sb-alien:define-alien-routine ("SDL_CloseAudioDevice" %sdl-close-audio) sb-alien:void
    (device sb-alien:unsigned-int))
  (sb-alien:define-alien-routine ("SDL_QueueAudio" %sdl-queue-audio) sb-alien:int
    (device sb-alien:unsigned-int) (data (* t)) (length sb-alien:unsigned-int))
  (sb-alien:define-alien-routine ("SDL_GetQueuedAudioSize" %sdl-queued-audio-size)
      sb-alien:unsigned-int (device sb-alien:unsigned-int))
  (sb-alien:define-alien-routine ("SDL_PauseAudioDevice" %sdl-pause-audio) sb-alien:void
    (device sb-alien:unsigned-int) (pause-on sb-alien:int)))

(defun audio-queue-open! (queue)
  #+sbcl
  (progn
    (let ((library (or (uiop:getenv "CL_NES_SDL2_LIBRARY")
                       #+darwin "/opt/homebrew/lib/libSDL2-2.0.0.dylib"
                       #-darwin "libSDL2-2.0.so")))
      (handler-case (sb-alien:load-shared-object library)
        (error (condition)
          (error "Could not load SDL2 (~A): ~A" library condition))))
    (unless (zerop (%sdl-init +sdl-init-audio+))
      (error "SDL audio initialization failed."))
    ;; SDL_AudioSpec is intentionally supplied as raw storage: this keeps the
    ;; frontend independent of an SDL Lisp package while retaining QueueAudio.
    (let ((spec (make-array 64 :element-type '(unsigned-byte 8) :initial-element 0)))
      (loop for shift from 0 below 32 by 8
            for index from 0
            do (setf (aref spec index)
                     (ldb (byte 8 shift) (audio-queue-sample-rate queue))))
      ;; SDL_AudioSpec: freq, format=S16LSB, channels=1, samples=1024.
      (setf (aref spec 4) (ldb (byte 8 0) +sdl-audio-s16lsb+)
            (aref spec 5) (ldb (byte 8 8) +sdl-audio-s16lsb+)
            (aref spec 6) 1 (aref spec 8) 0 (aref spec 9) 4)
      (sb-sys:with-pinned-objects (spec)
        (let ((device (%sdl-open-audio
                       (sb-sys:int-sap 0) 0 (sb-sys:vector-sap spec)
                       (sb-sys:int-sap 0) +sdl-audio-allow-frequency-change+)))
          (when (zerop device) (error "SDL audio device could not be opened."))
          (setf (audio-queue-device queue) device
                (audio-queue-opened-p queue) t)
          (%sdl-pause-audio device 0)))))
  #-sbcl (error "The frontend requires SBCL for SDL2 audio."))

(defun audio-queue-close! (queue)
  #+sbcl (when (audio-queue-opened-p queue)
           (%sdl-close-audio (audio-queue-device queue))
           (%sdl-quit +sdl-init-audio+))
  (setf (audio-queue-opened-p queue) nil)
  queue)

(defun audio-queue-push! (queue samples)
  "Queue signed 16-bit little-endian SAMPLES and return queued byte count."
  (unless (audio-queue-opened-p queue) (error "Audio queue is not open."))
  #+sbcl
  (let ((octets (make-array (* 2 (length samples))
                            :element-type '(unsigned-byte 8))))
    (loop for sample across samples for i from 0 by 2
          for value = (max -32768
                       (min 32767
                            (round (* (coerce sample 'double-float)
                                      32767d0))))
          do (setf (aref octets i) (ldb (byte 8 0) value)
                   (aref octets (1+ i)) (ldb (byte 8 8) value)))
    (sb-sys:with-pinned-objects (octets)
      (unless (zerop (%sdl-queue-audio (audio-queue-device queue)
                                       (sb-sys:vector-sap octets)
                                       (length octets)))
        (error "SDL audio queue failed.")))
    (setf (audio-queue-queued-bytes queue)
          (%sdl-queued-audio-size (audio-queue-device queue))))
  (audio-queue-queued-bytes queue))

(defun audio-queue-size (queue)
  #+sbcl (if (audio-queue-opened-p queue)
             (setf (audio-queue-queued-bytes queue)
                   (%sdl-queued-audio-size (audio-queue-device queue)))
             0)
  #-sbcl 0)

(defstruct (rate-controller (:constructor %make-rate-controller
                                      (target-low target-high base-delay)))
  target-low target-high base-delay (integral 0d0) (delay 0d0))

(defun make-rate-controller (&key (target-low 2048) (target-high 8192)
                                  (base-delay 0.0d0))
  (%make-rate-controller target-low target-high base-delay))

(defun rate-controller-update! (controller queued-bytes)
  "Update pacing from SDL's authoritative queue.

When the queue is below its target, the caller must not wait; when it is over
target, the bounded delay increases."
  (let* ((low (rate-controller-target-low controller))
         (high (rate-controller-target-high controller))
         (target (/ (+ low high) 2))
         (error (- (coerce queued-bytes 'double-float) target))
         (integral (max -100000d0 (min 100000d0
                                        (+ (rate-controller-integral controller)
                                           (* error 0.1d0))))))
    (setf (rate-controller-integral controller) integral
          (rate-controller-delay controller)
          (if (plusp error)
              (min 0.05d0
                   (+ (rate-controller-base-delay controller)
                      (* error 0.000002d0)
                      (* (max 0d0 integral) 0.00000002d0)))
              0d0))
    (rate-controller-delay controller)))
