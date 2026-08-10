# Core concepts

cl-nes models the console as a group of Common Lisp objects connected by the
CPU bus. The public API is deliberately headless: callers decide how to
render, play, record, or inspect the results.

## Cartridges and memory

load-cartridge reads an iNES byte vector or pathname and constructs a
cartridge. The parser validates the header, PRG and CHR sizes, mapper number,
and supported format features. A cartridge without CHR data receives writable
CHR-RAM. PRG-RAM defaults to 8 KiB.

The cartridge maps PRG-ROM, PRG-RAM, CHR-ROM or CHR-RAM, and mapper registers.
Nametable mirroring is retained as cartridge metadata and is used by the PPU.
cartridge-reset! resets mapper state while retaining cartridge RAM.

## Machine and timing

make-nes creates or accepts the cartridge, CPU, bus, PPU, controllers, and APU.
nes-load-cartridge! resets the connected machine around a new cartridge, while
nes-reset! resets the running machine.

nes-step/k executes one CPU instruction and calls a continuation with the final
CPU-cycle count. The PPU advances three ticks per CPU cycle and the APU
advances once per CPU cycle. OAM DMA and interrupt entry add their clocked
cycles to the result.

nes-run-frame/k keeps stepping until the PPU reports a completed frame, then
passes the framebuffer to its continuation.

## Bus and devices

The CPU bus mirrors internal RAM through $1FFF and PPU registers through $3FFF.
It also routes APU registers, OAM DMA, controllers, expansion space, PRG-RAM,
and cartridge PRG space. DMC reads use the same address space through a bus
memory-reader callback.

Controllers use an 8-bit button mask and the NES strobe/shift protocol. The PPU
owns registers, VRAM, OAM, palette memory, rendering state, and the framebuffer.
The APU maintains channel state and exposes a headless mixed sample.

## Mapper 4 variants

The iNES header identifies mapper 4 but does not identify the MMC3 versus MMC6
reload behavior used by some ROMs. cl-nes therefore defaults to the MMC3
variant and permits an explicit mapper4-variant choice of :mmc3 or :mmc6 in
make-cartridge and load-cartridge.
