# API reference

The public Common Lisp package is `cl-nes`. The names below are exported by
that package. Function arguments are shown in the same order as the public
definitions.

## Cartridges and ROM loading

| Name | Purpose |
| --- | --- |
| `cartridge` | Cartridge state and mapper interface. |
| `make-cartridge` | Construct a cartridge from octet sequences. Keywords are `:prg-rom`, `:chr-rom`, `:mapper`, `:mirroring`, `:battery-backed-p`, `:four-screen-p`, `:submapper`, `:bus-conflict-p`, `:chr-writable-p`, `:prg-ram-size`, and `:mapper4-variant`. Defaults are mapper 0, horizontal mirroring, 8 KiB PRG-RAM, and `:mmc3`; absent CHR-ROM creates writable CHR-RAM. |
| `load-cartridge` | Load iNES/NES 2 data from a pathname, string pathname, or octet vector. It accepts optional `:mapper4-variant` (`:mmc3`, `:mmc3-rev-a`, `:mmc6`, or `:mmc3-alt`) and signals `invalid-rom` or `unsupported-mapper` for invalid input. |
| `cartridge-reset!` | Reset mapper state while retaining cartridge RAM. |
| `cartridge-prg-rom`, `cartridge-chr-rom` | Access the PRG-ROM and CHR storage vectors. |
| `cartridge-prg-size`, `cartridge-chr-size` | Return PRG and CHR storage sizes in bytes. |
| `cartridge-prg-ram` | Access PRG-RAM. |
| `cartridge-mapper`, `cartridge-submapper`, `cartridge-mapper4-variant` | Access mapper metadata. |
| `cartridge-mirroring` | Return the nametable mirroring mode. |
| `cartridge-battery-backed-p`, `cartridge-battery-dirty-p` | Report battery-backed status and whether PRG-RAM has been modified. |
| `cartridge-clear-battery-dirty!` | Clear the battery dirty flag and return the cartridge. |
| `cartridge-four-screen-p`, `cartridge-chr-writable-p` | Report four-screen layout and whether CHR writes are enabled. |
| `cartridge-read-prg`, `cartridge-write-prg!` | Read or write mapper PRG space; the write also accepts an optional CPU-cycle value. |
| `cartridge-read-prg-ram`, `cartridge-write-prg-ram!` | Read or write PRG-RAM. |
| `cartridge-save-battery`, `cartridge-restore-battery!` | Copy battery-backed PRG-RAM to an octet vector, or restore an exactly sized vector. These signal `cartridge-battery-error` when the cartridge is not battery-backed, has no PRG-RAM, or the size is wrong. |
| `cartridge-read-chr`, `cartridge-write-chr!` | Read or write CHR space; reads accept an optional sprite-access flag. |
| `cartridge-clock-cpu!` | Advance mapper CPU-cycle timing, including mapper IRQ timing. |

`load-cartridge` honors the iNES trainer offset, battery and mirroring flags,
NES 2 submapper and RAM sizes, and derives the MMC3 variant from the submapper
unless `:mapper4-variant` is supplied explicitly.

## NES machine

| Name | Purpose |
| --- | --- |
| `nes` | Complete NES machine state. |
| `make-nes` | Construct a machine with optional `:cartridge`, `:ppu`, `:controller-1`, `:controller-2`, and `:apu`. |
| `nes-cpu`, `nes-bus`, `nes-ppu`, `nes-apu` | Access the connected devices. |
| `nes-load-cartridge!` | Install a cartridge, reset connected devices, and return the NES. |
| `nes-initialize!` | Reset the NES and optionally set the CPU program counter with `:pc`; return the NES. |
| `nes-reset!` | Reset CPU timing, mapper, PPU, APU, and bus DMA state while retaining RAM-like device storage. |
| `nes-save-state` | Return a deterministic `(vector (unsigned-byte 8))` containing CPU, PPU, APU, bus, controllers, cartridge, and NES state. |
| `nes-load-state` | Restore from an octet vector and return the NES. Device object identities remain stable; malformed, incompatible, truncated, or trailing data signals `invalid-savestate`. |
| `nes-step/k` | Execute one CPU instruction, then applicable DMA and interrupt clocks. Call the continuation with the total CPU-cycle count and return its result. `:cycle-hook`, when supplied, runs after every elapsed CPU cycle. |
| `nes-run-frame/k` | Run to the next frame boundary, call the continuation with the framebuffer, and return its result. `:cycle-hook` runs per CPU cycle; `:input-continuation` is called once with the NES before the first CPU step. |
| `nes-run-frames/k` | Run a positive frame count, calling the frame continuation once per frame. Optional `:sample-rate`, `:audio-buffer`, `:audio-continuation`, and `:input-continuation` configure audio and frame-boundary input. Return the NES. |

Save states begin with the `CLNS` magic and version 2. Older or newer versions
are rejected as incompatible; states are portable only among implementations
that support this format version and the serialized mapper/state data.

## Audio buffers and headless output

| Name | Purpose |
| --- | --- |
| `nes-audio-buffer` | Fixed-size reusable single-float audio buffer type. |
| `make-nes-audio-buffer` | Create a buffer with positive `:size` (default 1024). |
| `nes-audio-buffer-samples` | Access the simple single-float sample vector. |
| `nes-audio-buffer-count` | Access the number of currently valid samples. A full buffer is passed to the audio continuation, then its count is reset to zero. |
| `+nes-frame-width+`, `+nes-frame-height+` | Frame dimensions: 256 by 240. |
| `+nes-framebuffer-size+` | Number of palette-index pixels: 61,440. |
| `+nes-ntsc-cpu-frequency+` | NTSC CPU frequency used by output sample scheduling: 1,789,773 Hz. |
| `+nes-default-audio-sample-rate+` | Default output sample rate: 44,100 Hz. |
| `nes-framebuffer-rgb-octets` | Convert a framebuffer to packed RGB octets. Optional `:palette` must contain 192 RGB octets. |
| `nes-write-ppm` | Write a framebuffer as binary P6 PPM; optional `:palette`; return the pathname. |
| `nes-write-wav` | Write single-float mono samples as 16-bit PCM RIFF/WAVE. Optional positive `:sample-rate`; samples are clipped to `[-1, 1]`; return the pathname. |

When audio is enabled, `nes-run-frames/k` samples the APU mixer on the same
CPU-cycle clock used by PPU, APU, DMA, and interrupt timing. The supplied
buffer and continuation must be supplied together. Samples are single-float
values in the output buffer; the continuation receives the full buffer at the
selected sample rate.

## CPU and bus

| Name | Purpose |
| --- | --- |
| `cpu` | CPU state. |
| `make-cpu` | Construct a CPU. |
| `cpu-a`, `cpu-x`, `cpu-y` | Read the A, X, and Y registers. |
| `cpu-p`, `cpu-sp`, `cpu-pc` | Read status, stack pointer, and program counter. |
| `cpu-cycles` | Read accumulated CPU cycles. |
| `cpu-stopped-p` | Report whether the CPU has stopped. |
| `cpu-reset!` | Reset a CPU using a bus. |
| `cpu-step!` | Execute one CPU instruction using a bus. |
| `cpu-interrupt!` | Request an interrupt using a bus. |
| `bus` | CPU address-space and device-routing state. |
| `make-bus` | Connect optional cartridge, PPU, controllers, and APU. |
| `bus-apu` | Access the APU connected to a bus. |
| `bus-read`, `bus-write!` | Read or write a CPU bus address. OAM DMA writes participate in the modeled DMA stall and transfer. |

## PPU and APU

| Name | Purpose |
| --- | --- |
| `ppu` | PPU timing, memory, register, and framebuffer state. |
| `make-ppu` | Construct a PPU with an optional cartridge. |
| `ppu-reset!` | Reset PPU registers and timing while retaining VRAM, palette RAM, OAM, and framebuffer storage. |
| `ppu-load-cartridge!` | Connect a cartridge and reset PPU state. |
| `ppu-control`, `ppu-mask`, `ppu-status` | Access PPU register state. |
| `ppu-oam`, `ppu-oam-address` | Access OAM and its address. |
| `ppu-framebuffer` | Access the 256x240 palette-index framebuffer. |
| `ppu-frame-ready-p`, `ppu-nmi-pending-p` | Report frame and NMI pending state. |
| `ppu-read-register`, `ppu-write-register!` | Read or write a PPU register; reads accept an optional bus-access flag. |
| `ppu-tick!` | Advance PPU timing by an optional tick count (default one). |
| `ppu-take-nmi!` | Consume and return a pending NMI, if any. |
| `ppu-read-vram`, `ppu-write-vram!` | Read or write PPU VRAM; `ppu-read-vram` accepts an optional sprite-access flag. |
| `apu` | APU channel, frame-sequencer, and mixer state. |
| `make-apu` | Construct an APU with optional `:memory-reader` for DMC reads. |
| `apu-reset!` | Reset APU state. |
| `apu-set-memory-reader!` | Set the DMC CPU-memory reader. |
| `apu-read-register`, `apu-write-register!` | Read or write an APU register; reads optionally accept the CPU-cycle phase. |
| `apu-tick!` | Advance APU timing by a CPU-cycle count. |
| `apu-irq-pending-p` | Report pending APU frame IRQ state. |
| `apu-mix` | Return the current nonlinear hardware mix value. |

## Controllers

| Name | Purpose |
| --- | --- |
| `controller` | Serial controller state. |
| `make-controller` | Construct a controller. |
| `controller-buttons` | Read the current 8-bit button mask. |
| `controller-set-buttons!` | Set the button mask and return the controller. |
| `controller-write!` | Drive the serial strobe protocol; accepts `:strobe-p` and returns the controller. |
| `controller-read` | Read the next serial button bit. |
| `+button-a+`, `+button-b+`, `+button-select+`, `+button-start+` | Button mask constants for A, B, Select, and Start. |
| `+button-up+`, `+button-down+`, `+button-left+`, `+button-right+` | Button mask constants for the four directions. |

## ROM protocol and result APIs

The protocol helpers are reusable for ROM diagnostics and do not change the
frontend package. `protocol-run-frames-until` runs at most `max-frames` and
returns the frame at which the predicate succeeds, or `max-frames` if it does
not.

| Name | Purpose |
| --- | --- |
| `protocol-bus-range` | Return bus bytes from inclusive `start` through `end`. |
| `protocol-ascii-result` | Decode printable bytes and trim spaces, tabs, returns, newlines, NULs, and periods. |
| `protocol-nametable-text` | Decode a nametable region to text. Keywords are `:start` (default `#x2000`), `:columns` (32), `:rows` (30), and `:tile-map` (`#'code-char`). The tile mapper receives each tile number and may return a character or NIL. |
| `protocol-ram-result-p` | Compare an actual result byte with an expected byte. |
| `protocol-text-result-p` | Test whether expected text occurs, case-insensitively, in the result text. |
| `protocol-blargg-complete-p` | Test Blargg `$6000` status/signature completion. |
| `protocol-running-result-complete-p` | Test completion after a result leaves a supplied running value. |
| `run-blargg-protocol` | Run a ROM's `$6000` status/signature protocol. Returns a plist with `:passed`, `:frames`, `:text`, `:status`, `:signature`, and `:running-observed`; accepts `:mapper4-variant`. |
| `run-ram-result-protocol` | Run a ROM and compare `result-address` with `expected`; accepts `:mapper4-variant` and `:running-value`. Returns `:passed`, `:frames`, `:result`, `:result-address`, `:expected`, `:text`, and `:running-observed`. |
| `run-text-progress-protocol` | Run a legacy ROM whose result is text at the Blargg text port; accepts `:mapper4-variant` and returns `:passed`, `:frames`, and `:text`. |
| `run-nametable-text-protocol` | Run and compare decoded nametable text; accepts `:start`, `:columns`, `:rows`, `:tile-map`, and `:mapper4-variant`, returning `:passed`, `:frames`, and `:text`. |
| `run-mmc1-a12-protocol` | Run the MMC1 A12/WRAM-gate probe and return `:passed`, `:frames`, and the final `$6000` `:probe` value. |
| `run-accuracy-coin-protocol` | Run AccuracyCoin with Start input and return `:frames`, `:results` for `$0400-$04FF`, and `:shared-draw` from `$03FF`. |

## Conditions

| Name | Accessors and meaning |
| --- | --- |
| `nes-error` | Base condition for public NES errors. |
| `invalid-rom` | Invalid ROM data; `invalid-rom-reason` returns the reason. |
| `unsupported-mapper` | Unsupported mapper; `unsupported-mapper-number` returns its number. |
| `cartridge-battery-error` | Battery operation failure; `cartridge-battery-error-reason`, `cartridge-battery-error-expected-size`, and `cartridge-battery-error-actual-size` describe it. |
| `invalid-savestate` | Invalid save-state data; `invalid-savestate-reason` returns the reason. |

## Frontend command line

The separate `cl-nes` executable exposes `play`, `render`, and `rom-test`.
`--version` prints the frontend version without a ROM.

```text
cl-nes play ROM [--state-directory PATH] [--scale INTEGER]
cl-nes render ROM [--frames INTEGER] [--prefix PREFIX] [--format ppm|png]
cl-nes rom-test ROM [--max-frames INTEGER] [--mapper4-variant mmc3|mmc6|mmc3-alt]
```

`play` defaults to `--state-directory ./` and `--scale 3`. `render` defaults
to one frame, prefix `frame`, and `ppm`. `rom-test` defaults to 360 frames;
with `--mapper4-variant` it runs the Blargg `$6000` protocol and reports pass,
frames, status, signature, and text. Without that option it uses the frontend's
legacy ROM-test path. The commands require a ROM path and do not download ROMs.
The CLI currently accepts `mmc3`, `mmc6`, and `mmc3-alt`; the library API also
accepts `:mmc3-rev-a`.
