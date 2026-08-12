(in-package #:cl-nes)

;; The APU is deliberately kept headless.  It implements the CPU-visible
;; registers, frame sequencer, channel timers, length/envelope state, and a
;; small integer mixer.  A frontend can sample APU-SAMPLE without requiring a
;; platform audio library.  Hardware tables live in APU-DATA.LISP and state
;; types live in APU-STATE.LISP.

(defun apu-set-memory-reader! (apu reader)
  "Set the function used by the DMC to read the CPU address space.

READER receives a 16-bit address and must return an 8-bit value.  A bus
created by MAKE-BUS installs this callback automatically; this setter keeps a
standalone APU useful for tests and small frontends as well."
  (setf (apu-memory-reader apu) reader)
  apu)

(defun apu-reset! (apu)
  (%apu-reset-frame-state! apu)
  (let ((pulse-1 (apu-pulse-1 apu))
        (pulse-2 (apu-pulse-2 apu))
        (triangle (apu-triangle apu))
        (noise (apu-noise apu))
        (dmc (apu-dmc apu)))
    (%apu-reset-pulse! pulse-1)
    (%apu-reset-pulse! pulse-2)
    (%apu-reset-triangle! triangle)
    (%apu-reset-noise! noise)
    (%apu-reset-dmc! dmc))
  apu)
