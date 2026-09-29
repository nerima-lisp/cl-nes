# Architecture

cl-nes is organized as a dependency-ordered set of Common Lisp source files.
The layers are connected through explicit objects rather than global emulator
state.

## Source layers

1. Package definitions, conditions, macros, and shared data.
2. Cartridge format parsing, cartridge storage, mapper implementations, and
   cartridge memory. Cartridge memory itself is split into address-layout
   helpers, storage accessors, and CPU/PPU routing so mapper translation can
   evolve without obscuring the bus boundary.
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

### Dot-level PPU timing

The PPU advances one dot at a time through `ppu-tick!`. Each dot updates the
decay clock and delayed rendering mask, renders the current pixel, shifts the
background registers, performs the fetch pipeline and sprite work scheduled
for that dot, and clocks the cartridge's PPU address-line timing. The PPU
tracks `scanline` and `dot` explicitly, including visible scanlines,
post-render, vblank, pre-render, odd-frame skip, NMI timing, and the 341-dot
scanline boundary. CPU execution therefore observes three PPU dots per CPU
cycle rather than a frame-level rendering approximation.

### DMA state machine

DMA is represented in bus state, not as a blocking bulk copy. OAM DMA records
whether it is active, its source page, byte index, transfer stage, alignment
phase, and pending stall cycles. The execution loop consumes the stall one CPU
bus cycle at a time; OAM transfer alternates source reads and OAM writes, and
the initial halt/alignment phase accounts for the 513/514-cycle parity
difference. DMC DMA has separate remaining-cycle and read-replay state so a
halted CPU bus access can be replayed after DMC dummy reads.

## State definitions and save states

Hardware state is declared with the `define-hardware-state` macro. A
definition supplies slot defaults, type metadata, constructor exclusions, and
generated accessors. It also generates symmetric binary state codecs. The
`nes-save-state` and `nes-load-state` functions compose and restore versioned
sections for the NES, CPU, bus, PPU, APU, controllers, and cartridge mapper
state. Load validates the magic, version, section lengths, and trailing data
before restoring state; invalid or truncated input signals
`invalid-savestate` rather than partially loading.

Save states are core byte vectors. The frontend adds ten ROM-identity-scoped
slots and atomically persists them; persistence is not part of normal core
execution.

## Cartridge boundary

The cartridge owns mapper state, ROM and RAM storage, mirroring metadata, and
mapper-specific address translation. The bus does not need to know the
individual mapper implementation. A mapper reset reinitializes its registers
without clearing cartridge RAM.

## Frontend boundary

`frontend/` is an adapter layer around the headless core. `input.lisp` maps
keyboard and gamepad input to controller masks; `video.lisp` and `render.lisp`
consume framebuffer data for the interactive window and PPM/PNG output;
`audio.lisp` queues APU samples through SDL2; `persistence.lisp` implements
ROM-hash-scoped battery and save-state files; `play.lisp` owns the interactive
loop and pacing; and `cli.lisp` assembles the `play`, `render`, and `rom-test`
commands. These adapters may perform file, window, and device I/O, while the
core remains headless.

## I/O boundary

The core performs no file, window, or audio-device work during normal machine
execution. load-cartridge and the command-line wrappers handle file input.
Applications can feed controller masks, inspect CPU/PPU/APU state, and route
frame or sample data to their own backends. The shipped frontend is one such
consumer, not a dependency of the emulator core.
