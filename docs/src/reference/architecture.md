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

The macro layer is intentionally focused. `with-bus-cpu-access-hook` owns
temporary bus-hook scopes and restores the previous hook even when execution
exits non-locally. `with-nes-cpu-operation` composes that scope to account for
CPU-visible accesses and internal cycles. `with-ppu-frame-index` keeps the
framebuffer addressing rule in one place so background and sprite compositing
share the same index calculation. Runtime state transitions stay in functions
so instruction dispatch, emulator state, and debugger-visible behavior remain
explicit.

APU reset is also split by concern: low-level channel and frame reset helpers
live in `src/apu-reset-helpers.lisp`, while `src/apu.lisp` remains the public
API boundary for standalone APU setup and whole-device reset entry points.

APU timer state is now split the same way: pulse, triangle, and noise timer
advancement stays in `src/apu-timers.lisp`, while DMC sample fetch, address
advance, and output-bit timing live in `src/apu-dmc-helpers.lisp`.

PPU lifecycle is split the same way: reset-state helpers and cartridge-backed
nametable sizing live in `src/ppu-reset-helpers.lisp`, while `src/ppu.lisp`
remains the public API boundary for standalone PPU setup and reset entry
points.

## Runtime flow

The CPU reads and writes through the bus. The bus dispatches addresses to RAM,
PPU registers, APU registers, controllers, DMA, expansion space, and the
cartridge. A CPU cycle advances the PPU three times and the APU once.

nes-step/k executes an instruction, clocks any DMA or interrupt entry, and
reports the resulting CPU-cycle count through its continuation.
nes-run-frame/k repeats this process until the PPU reaches its frame boundary.
The PPU framebuffer and APU sample remain data values for the caller to
consume.

NES execution is also split by concern: interrupt, NMI, and post-instruction
boundary helpers live in `src/nes-execution-helpers.lisp`, while
`src/nes-execution.lisp` remains the CPS-oriented orchestration boundary that
exposes `nes-step/k` and `nes-run-frame/k`.

PPU rendering is split by concern: background sampling lives in
`src/ppu-rendering-background.lisp`, sprite geometry and pattern/palette
resolution live in `src/ppu-rendering-sprite-helpers.lisp`, sprite sampling
and composition live in `src/ppu-rendering-sprites.lisp`, and
`src/ppu-rendering.lisp` remains the orchestration boundary consumed by the
rest of the core.

CPU opcode dispatch follows the same boundary. Declarative opcode tables for
the `#x00-#x7F` and `#x80-#xFF` ranges live in
`src/cpu-opcodes-00-7f-data.lisp` and `src/cpu-opcodes-80-ff-data.lisp`,
while the corresponding runtime files keep the irregular handlers and dispatch
entry points that still need direct control flow.

## Cartridge boundary

The cartridge owns mapper state, ROM and RAM storage, mirroring metadata, and
mapper-specific address translation. The bus does not need to know the
individual mapper implementation. A mapper reset reinitializes its registers
without clearing cartridge RAM.

MMC5-specific code is also split by concern: EXRAM access and nametable/fill
helpers live in `src/cartridge-mapper5-exram.lisp`, the fixed expansion
register map lives in `src/cartridge-mapper5-control-data.lisp`, register
dispatch and side-effect handling live in `src/cartridge-mapper5-control.lisp`,
and scanline IRQ handling lives in `src/cartridge-mapper5-irq.lisp`.

Mapper 4 follows the same split: PRG/CHR bank translation and register decode
stay in `src/cartridge-mapper4.lisp`, while IRQ counter and PPU A12 edge
tracking live in `src/cartridge-mapper4-irq.lisp`.

PRG access is split the same way: mapper-specific PRG register writes live in
`src/cartridge-prg-register-helpers.lisp`, while `src/cartridge-prg-access.lisp`
keeps ROM/RAM address translation and writability policy at the cartridge
boundary.

Mapper 22 and 28 now follow the same split: VRC2 nibble-register decode and
Action 53 register-select side effects live in
`src/cartridge-mapper22-28-helpers.lisp`, while
`src/cartridge-mapper22-28.lisp` keeps the PRG offset math and mapper write
entry points.

PPU cartridge access now follows the same boundary: CHR bank translation,
nametable mirroring index selection, and MMC5 nametable routing helpers live in
`src/cartridge-ppu-memory-helpers.lisp`, while
`src/cartridge-ppu-memory.lisp` keeps the public CHR and nametable read/write
entry points.

Cartridge state is also split by role: shared storage and bank-size constants
live in `src/cartridge-layout-data.lisp`, while `src/cartridge-state.lisp`
keeps the `cartridge` struct layout itself.

## I/O boundary

The core performs no file, window, or audio-device work during normal machine
execution. load-cartridge and the command-line wrappers handle file input.
Applications can feed controller masks, inspect CPU/PPU/APU state, and route
frame or sample data to their own backends.
