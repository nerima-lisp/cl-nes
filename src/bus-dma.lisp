(in-package #:cl-nes)

(defun %perform-oam-dma! (bus page)
  (let ((base (ash (logand page #xFF) 8)))
    ;; The transfer is a device operation. Its 256 source reads must not be
    ;; counted as 256 additional CPU bus cycles by the instruction hook.
    (with-bus-cpu-access-hook (bus nil)
      (loop for offset below 256 do
        (ppu-write-register! (bus-ppu bus) 4
                             (bus-read bus (+ base offset)))))
    ;; DMA occupies 513 or 514 CPU cycles depending on the phase of the CPU
    ;; cycle on which $4014 was written.  The transfer itself is already
    ;; complete; NES consumes this stall after the instruction returns.
    (setf (bus-dma-stall-cycles bus)
          (+ (bus-dma-stall-cycles bus)
             513
             (bus-cpu-cycle-phase bus)))))

(defun bus-take-dma-stall-cycles! (bus)
  (prog1 (bus-dma-stall-cycles bus)
    (setf (bus-dma-stall-cycles bus) 0)))
