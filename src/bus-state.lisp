(in-package #:cl-nes)

(defstruct (bus
            (:constructor %make-bus
                (cartridge ppu controller-1 controller-2 apu)))
  cartridge
  ppu
  controller-1
  controller-2
  apu
  (ram (make-array 2048 :element-type '(unsigned-byte 8)
                   :initial-element 0)
       :type vector)
  (open-bus 0 :type (unsigned-byte 8))
  (dma-stall-cycles 0 :type fixnum)
  ;; NES installs this only while executing a CPU operation. Device-internal
  ;; reads (for example DMC and OAM DMA) deliberately run with it disabled.
  (cpu-access-hook nil))
