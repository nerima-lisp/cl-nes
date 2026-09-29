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
  ;; The last CPU bus operation is repeated on DMC halt/dummy cycles.
  (last-cpu-access-kind :read)
  (last-cpu-access-address 0 :type (unsigned-byte 16))
  ;; Parity of the next CPU bus cycle, used by OAM DMA timing.
  (cpu-cycle-phase 0 :type fixnum)
  ;; NES installs this only while executing a CPU operation. Device-internal
  ;; reads (for example DMC and OAM DMA) deliberately run with it disabled.
  (cpu-access-hook nil))
