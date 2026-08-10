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

## Mapper 4

Mapper 4 defaults to the MMC3 IRQ reload behavior. Some ROMs need the MMC6
variant, which can be selected explicitly with mapper4-variant :mmc6. The
header does not provide enough information to choose between these revisions.

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
