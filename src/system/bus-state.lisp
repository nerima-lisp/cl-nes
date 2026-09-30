(in-package #:cl-nes)

(define-hardware-state bus
  ((cartridge nil nil)
   (ppu nil nil)
   (controller-1 nil nil)
   (controller-2 nil nil)
   (apu nil nil)
   (ram (make-array 2048 :element-type '(unsigned-byte 8) :initial-element 0) vector)
   (open-bus 0 (unsigned-byte 8))
   (dma-stall-cycles 0 fixnum)
   (oam-dma-active-p nil nil)
   (oam-dma-page 0 (unsigned-byte 8))
   (oam-dma-index 0 fixnum)
   (oam-dma-stage :halt)
   (oam-dma-alignment-p nil nil)
   (dmc-dma-remaining 0 fixnum)
   (dmc-read-replay-p nil nil)
   (dma-cycle-preempted-p nil nil)
  ;; The last CPU bus operation is repeated on DMC halt/dummy cycles.
   (last-cpu-access-kind :read)
   (last-cpu-access-address 0 (unsigned-byte 16))
  ;; Parity of the next CPU bus cycle, used by OAM DMA timing.
   (cpu-cycle-phase 0 fixnum)
  ;; NES installs this only while executing a CPU operation. Device-internal
  ;; reads (for example DMC and OAM DMA) deliberately run with it disabled.
   (cpu-access-hook nil)
   (cpu-access-active-p nil nil)
   (cpu-access-nes nil nil)
   (cpu-access-cycle-hook nil)
   (cpu-access-pre-cycle-hook nil)
   (cpu-access-count 0 fixnum))
  :constructor %make-bus
  :exclude (cartridge ppu controller-1 controller-2 apu
             cpu-access-hook cpu-access-nes cpu-access-cycle-hook
             cpu-access-pre-cycle-hook))
