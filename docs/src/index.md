# cl-nes

cl-nes is a headless Nintendo Entertainment System core written in Common
Lisp. It exposes the emulated machine as data and functions, leaving display,
audio, input, and process control to the caller.

## What it provides

- iNES 1.0 and the supported subset of NES 2.0 cartridge headers.
- Mappers 0, 1, 2, 3, 4, 5, 7, 9, 10, 11, 22, 28, 34, 66, 71, and 87.
- 6502/2A03 execution with reset, IRQ, NMI, stack operations, page-crossing
  cycles, and documented unofficial opcodes used by common test ROMs.
- CPU RAM and PPU register mirroring, controllers, and OAM DMA.
- PPU CHR-ROM/CHR-RAM, nametable and palette memory, scrolling, attributes,
  sprites, sprite-zero hit, and a framebuffer.
- APU pulse, triangle, noise, and DMC state handling, frame sequencing, frame
  IRQ, and an unsigned 8-bit headless sample.

## Boundaries

The core has no graphical or audio backend. A frame is delivered as a
framebuffer vector and an audio sample is returned by the APU API. DMC sample
fetching is connected to the CPU address space when the APU is created through
the bus; a standalone APU can receive a reader with
apu-set-memory-reader!. Some PPU and mapper timing paths are intentionally
coarse, so the stepping API is not a cycle-exact hardware bus trace.

Unsupported mappers, malformed ROMs, and unsupported CPU opcodes signal
conditions rather than being silently accepted.

## Where to go next

- [Getting started](getting-started.md) builds a machine and runs a frame.
- [Core concepts](guide/core-concepts.md) explains the cartridge, bus, and
  headless execution model.
- [Recipes](guide/recipes.md) shows common input and output integrations.
- [API reference](reference/api.md) lists the public constructors, accessors,
  and operations.
- [Compatibility](reference/compatibility.md) records the supported subset and
  known boundaries.
- [Development](project/development.md) describes tests, coverage, and docs.
