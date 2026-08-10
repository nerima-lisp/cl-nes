# Architecture

cl-nes is organized as a dependency-ordered set of Common Lisp source files.
The layers are connected through explicit objects rather than global emulator
state.

## Source layers

1. Package definitions, conditions, macros, and shared data.
2. Cartridge format parsing, cartridge storage, mapper implementations, and
   cartridge memory.
3. Controllers, APU data/state, and APU register, timing, and mixing behavior.
4. The PPU, rendering helpers, and timing.
5. The CPU bus and CPU instruction execution.
6. NES construction and instruction/frame execution.

The ASDF definition loads these layers in dependency order. The test runner
loads the test components in the same dependency-aware order.

The macro layer is intentionally small. `with-bus-cpu-access-hook` owns
temporary bus-hook scopes and restores the previous hook even when execution
exits non-locally. `with-nes-cpu-operation` composes that scope to account for
CPU-visible accesses and internal cycles. Runtime state transitions stay in
functions so instruction dispatch, emulator state, and debugger-visible
behavior remain explicit.

## Runtime flow

The CPU reads and writes through the bus. The bus dispatches addresses to RAM,
PPU registers, APU registers, controllers, DMA, expansion space, and the
cartridge. A CPU cycle advances the PPU three times and the APU once.

nes-step/k executes an instruction, clocks any DMA or interrupt entry, and
reports the resulting CPU-cycle count through its continuation.
nes-run-frame/k repeats this process until the PPU reaches its frame boundary.
The PPU framebuffer and APU sample remain data values for the caller to
consume.

## Cartridge boundary

The cartridge owns mapper state, ROM and RAM storage, mirroring metadata, and
mapper-specific address translation. The bus does not need to know the
individual mapper implementation. A mapper reset reinitializes its registers
without clearing cartridge RAM.

## I/O boundary

The core performs no file, window, or audio-device work during normal machine
execution. load-cartridge and the command-line wrappers handle file input.
Applications can feed controller masks, inspect CPU/PPU/APU state, and route
frame or sample data to their own backends.
