# Compatibility

This page describes the implemented subset. It is not a claim of complete
hardware compatibility.

## Cartridge formats

The parser accepts iNES 1.0 and the supported subset of NES 2.0 headers. The
supported mapper numbers are:

0, 1, 2, 3, 4, 5, 7, 11, 22, 28, and 34.

PRG-ROM and CHR-ROM are banked according to the mapper. A cartridge with no
CHR-ROM receives writable CHR-RAM. PRG-RAM, battery-backed state, four-screen
metadata, and nametable mirroring are represented where the header and mapper
support them.

## ROM verification evidence

External validation artifacts are kept outside the checkout. Their records
include the source revision, per-file SHA-256, and available license or
permission metadata; ROM binaries are not part of the repository.

For the current validation run, each valid manifest entry was executed in a
fresh emulator process with a bounded wall-clock limit. Every valid iNES or
NES 2.0 entry in the public test-ROM manifest reached 10 frames, covering all
mapper numbers listed above. A separate homebrew corpus reached 60 frames per
entry. A malformed ROM was reported as `invalid` and excluded from the valid
ROM pass.

These results verify bounded loading, mapper selection, reset execution, and
continued frame progression. They do not verify reference framebuffer output,
interactive controls, audio fidelity, exact cycle traces, or compatibility
with every NES game.

The reset and initial execution phase was also compared with the public
`nestest` reference log. Starting the test at `$C000`, the first eight
instructions matched for CPU registers, PPU scanline/dot position, and CPU
cycle count. This check covers the reset phase and its immediate execution
path; it is not a claim that every timing edge is cycle exact.

## Mapper 4

Mapper 4 defaults to the MMC3 IRQ reload behavior. Some ROMs need the
zero-counter reload suppression behavior shared by MMC6-compatible revisions;
select it explicitly with mapper4-variant :mmc6 or :mmc3-alt. The header does
not provide enough information to choose between these revisions.

## CPU and PPU

The CPU implements the 6502/2A03 instruction set used by the core, including
documented unofficial opcodes used by common test ROMs, stack operations,
interrupt entry, reset, and page-crossing cycle behavior. The PPU implements
CHR-ROM/CHR-RAM access, nametable and palette memory, scrolling, attributes,
sprites, sprite-zero hit, vblank/NMI state, and a 256x240 framebuffer.

PPU and mapper timing is intentionally coarse in some compatibility-sensitive
paths. nes-step/k is therefore an instruction-oriented headless API, not a
cycle-exact hardware trace.

## APU and controllers

The APU models pulse, triangle, noise, and DMC register/state behavior, frame
sequencing, frame IRQ, status reads, and a headless mixed sample. DMC memory
reads use the CPU bus when the APU is connected to one.

Controllers implement the standard eight-button mask and serial strobe/shift
behavior. OAM DMA is routed through the CPU bus and contributes its stall
cycles to instruction stepping.

## Unsupported behavior

Unsupported mapper numbers, unsupported ROM header features, malformed ROM
data, and unsupported CPU opcodes signal conditions. The project does not
provide a graphical window, audio output device, or a promise that every NES
timing edge is reproduced.
