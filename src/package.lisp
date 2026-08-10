(in-package #:cl-user)

(defpackage #:cl-nes
  (:use #:cl)
  (:export
   ;; Errors
   #:nes-error
   #:invalid-rom
   #:invalid-rom-reason
   #:unsupported-mapper
   #:unsupported-mapper-number
   #:illegal-opcode
   #:illegal-opcode-value
   #:illegal-opcode-address

   ;; Cartridges
   #:cartridge
   #:make-cartridge
   #:cartridge-reset!
   #:load-cartridge
   #:cartridge-prg-rom
   #:cartridge-chr-rom
   #:cartridge-prg-ram
   #:cartridge-mapper
   #:cartridge-mapper4-variant
   #:cartridge-mirroring
   #:cartridge-battery-backed-p
   #:cartridge-four-screen-p
   #:cartridge-chr-writable-p
   #:cartridge-read-prg
   #:cartridge-write-prg!
   #:cartridge-read-prg-ram
   #:cartridge-write-prg-ram!
   #:cartridge-read-chr
   #:cartridge-write-chr!

   ;; Controllers
   #:+button-a+
   #:+button-b+
   #:+button-select+
   #:+button-start+
   #:+button-up+
   #:+button-down+
   #:+button-left+
   #:+button-right+
   #:controller
   #:make-controller
   #:controller-buttons
   #:controller-set-buttons!
   #:controller-write!
   #:controller-read

   ;; APU
   #:apu
   #:make-apu
   #:apu-reset!
   #:apu-set-memory-reader!
   #:apu-read-register
   #:apu-write-register!
   #:apu-tick!
   #:apu-irq-pending-p
   #:apu-sample

   ;; PPU
   #:ppu
   #:make-ppu
   #:ppu-reset!
   #:ppu-load-cartridge!
   #:ppu-control
   #:ppu-mask
   #:ppu-status
   #:ppu-oam
   #:ppu-oam-address
   #:ppu-framebuffer
   #:ppu-frame-ready-p
   #:ppu-nmi-pending-p
   #:ppu-read-register
   #:ppu-write-register!
   #:ppu-tick!
   #:ppu-take-nmi!
   #:ppu-read-vram
   #:ppu-write-vram!

   ;; CPU and bus
   #:cpu
   #:make-cpu
   #:cpu-a
   #:cpu-x
   #:cpu-y
   #:cpu-p
   #:cpu-sp
   #:cpu-pc
   #:cpu-cycles
   #:cpu-stopped-p
   #:cpu-reset!
   #:cpu-step!
   #:cpu-interrupt!
   #:bus
   #:make-bus
   #:bus-apu
   #:bus-read
   #:bus-write!

   ;; System
   #:nes
   #:make-nes
   #:nes-cpu
   #:nes-bus
   #:nes-ppu
   #:nes-apu
   #:nes-load-cartridge!
   #:nes-reset!
   #:nes-step/k
   #:nes-run-frame/k))
