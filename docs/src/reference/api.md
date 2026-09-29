# API reference

The public package is cl-nes. The sections below group its exported
constructors, accessors, state operations, and constants.

## Cartridges

| Name | Purpose |
| --- | --- |
| cartridge | Cartridge state and mapper interface. |
| make-cartridge | Construct a cartridge from PRG-ROM and optional CHR-ROM vectors. |
| load-cartridge | Parse an iNES byte vector or pathname. Accepts mapper4-variant. |
| cartridge-reset! | Reset mapper registers while retaining cartridge RAM. |
| cartridge-prg-rom, cartridge-chr-rom | Return the cartridge ROM vectors. |
| cartridge-prg-size, cartridge-chr-size | Return the PRG-ROM and CHR storage sizes in bytes. |
| cartridge-prg-ram | Return PRG-RAM. |
| cartridge-mapper, cartridge-submapper, cartridge-mapper4-variant | Return mapper metadata. |
| cartridge-mirroring | Return the nametable mirroring mode. |
| cartridge-battery-backed-p, cartridge-four-screen-p | Return header flags. |
| cartridge-chr-writable-p | Report whether CHR writes are enabled. |
| cartridge-read-prg, cartridge-write-prg! | Read or write mapper PRG space. |
| cartridge-read-prg-ram, cartridge-write-prg-ram! | Read or write PRG-RAM. |
| cartridge-save-battery, cartridge-restore-battery! | Copy or restore battery-backed PRG-RAM. |
| cartridge-read-chr, cartridge-write-chr! | Read or write CHR space. |

make-cartridge accepts prg-rom, chr-rom, mapper, mirroring, battery-backed-p,
four-screen-p, chr-writable-p, prg-ram-size, and mapper4-variant. When chr-rom
is absent, writable CHR-RAM is created.
The mapper4-variant values are :mmc3 (default), :mmc6, and :mmc3-alt.

## NES machine

| Name | Purpose |
| --- | --- |
| nes | Complete NES machine state. |
| make-nes | Construct a machine, optionally supplying cartridge, PPU, controllers, or APU. |
| nes-cpu, nes-bus, nes-ppu, nes-apu | Access the connected devices. |
| nes-load-cartridge! | Install a cartridge and reset the connected machine. |
| nes-reset! | Reset the machine. |
| nes-step/k | Execute one CPU instruction and call a continuation with cycle count. |
| nes-run-frame/k | Run until a frame is ready and call a continuation with the framebuffer. |
| nes-run-frames/k | Run frames and fill reusable fixed-size audio buffers through CPS. |

The continuation passed to nes-step/k receives the final CPU-cycle count after
DMA and interrupt clocks. The continuation passed to nes-run-frame/k receives
the PPU framebuffer. The optional :cycle-hook keyword on these functions is
called once after each elapsed CPU cycle, including DMA and interrupt clocks.
The optional :input-continuation keyword on nes-run-frame/k is called once
with the nes instance before the frame's first CPU step, letting a caller
update controller state at the frame boundary.

## CPU and bus

| Name | Purpose |
| --- | --- |
| cpu | CPU state and execution interface. |
| make-cpu | Construct a CPU, normally with a bus. |
| cpu-a, cpu-x, cpu-y | Read the A, X, and Y registers. |
| cpu-p, cpu-sp, cpu-pc | Read status, stack pointer, and program counter. |
| cpu-cycles | Read the accumulated CPU-cycle count. |
| cpu-stopped-p | Report whether execution has stopped. |
| cpu-reset! | Reset the CPU. |
| cpu-step! | Execute one CPU instruction. |
| cpu-interrupt! | Request an interrupt. |
| bus | CPU address-space and device-routing state. |
| make-bus | Connect CPU, PPU, APU, controllers, and cartridge address spaces. |
| bus-apu | Access the APU connected to a bus. |
| bus-read, bus-write! | Read or write a CPU bus address. |

The bus maps CPU RAM, PPU registers, APU registers, controllers, expansion
space, PRG-RAM, and cartridge PRG-ROM. Writing the OAM DMA register performs the
corresponding DMA stall and transfer.

## PPU

| Name | Purpose |
| --- | --- |
| ppu | PPU state, timing, and framebuffer interface. |
| make-ppu | Construct a PPU. |
| ppu-reset! | Reset PPU registers and timing state. |
| ppu-load-cartridge! | Connect a cartridge to the PPU. |
| ppu-control, ppu-mask, ppu-status | Read PPU register state. |
| ppu-oam, ppu-oam-address | Access OAM and its address. |
| ppu-framebuffer | Access the 256x240 framebuffer. |
| ppu-frame-ready-p | Report whether a frame boundary was reached. |
| ppu-nmi-pending-p, ppu-take-nmi! | Inspect or consume a pending NMI. |
| ppu-read-register, ppu-write-register! | Read or write a PPU register. |
| ppu-tick! | Advance PPU timing. |
| ppu-read-vram, ppu-write-vram! | Read or write VRAM through PPU addressing. |

## APU

| Name | Purpose |
| --- | --- |
| apu | APU channel and mixer state. |
| make-apu | Construct an APU. |
| apu-reset! | Reset channel and frame-sequencer state. |
| apu-set-memory-reader! | Supply a function for DMC CPU-memory reads. |
| apu-read-register, apu-write-register! | Read or write APU registers. |
| apu-tick! | Advance APU timing by one CPU-cycle tick. |
| apu-irq-pending-p | Report a pending frame IRQ. |
| apu-mix | Return the current nonlinear hardware mix in the range 0..1. |

## Headless output

| Name | Purpose |
| --- | --- |
| +nes-frame-width+, +nes-frame-height+ | Frame dimensions, 256x240. |
| +nes-framebuffer-size+ | Number of palette-index pixels in a framebuffer. |
| +nes-ntsc-cpu-frequency+ | CPU frequency used for output sample scheduling. |
| +nes-default-audio-sample-rate+ | Default audio sample rate, 44100 Hz. |
| nes-framebuffer-rgb-octets | Convert a palette-index framebuffer to packed RGB octets. |
| nes-write-ppm | Write a framebuffer as a binary P6 PPM image. |
| nes-write-wav | Write centered single-float mono samples as 16-bit PCM RIFF/WAVE. |

nes-run-frames/k calls its frame continuation once per completed frame. Pass
`:audio-buffer` from `make-nes-audio-buffer` and `:audio-continuation` to
receive that same buffer whenever it is full. Each buffer contains
single-float samples in `[-1,1]`; `nes-audio-buffer-count` is the number of
valid samples (the callback receives a full buffer). `:sample-rate` selects
the requested output rate. The resampler is a blip-buffer style band-limited
step synthesizer with a 256-tap, 64-phase Blackman table. A cycle only
compares the current mixer value; the table is accumulated when a step occurs,
and output samples integrate the pending impulse. This keeps the per-cycle
steady-state path allocation-free while the measured 30 kHz third harmonic
at 48 kHz is -61.88 dB. The
optional `:input-continuation` is called once per frame before its first CPU
step.

## Controllers

| Name | Value or purpose |
| --- | --- |
| controller | Serial controller state. |
| +button-a+, +button-b+ | A and B button bits. |
| +button-select+, +button-start+ | Select and Start button bits. |
| +button-up+, +button-down+ | Up and Down button bits. |
| +button-left+, +button-right+ | Left and Right button bits. |
| make-controller | Construct a controller. |
| controller-buttons | Read the current button mask. |
| controller-set-buttons! | Set the current button mask. |
| controller-write!, controller-read | Drive or read the serial controller protocol. |

## Conditions

The exported condition types are nes-error, invalid-rom, and
unsupported-mapper. Their accessors are invalid-rom-reason and
unsupported-mapper-number. See [Conditions](conditions.md) for handling examples.
