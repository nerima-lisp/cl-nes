# Compatibility

This page describes the implemented subset. It is not a claim of complete
hardware compatibility.

## Cartridge formats

The parser accepts iNES 1.0 and the supported subset of NES 2.0 headers. The
supported mapper numbers are:

0, 1, 2, 3, 4, 5, 7, 9, 10, 11, 22, 28, 34, 66, 69, 71, 79, and 87.

PRG-ROM and CHR-ROM are banked according to the mapper. A cartridge with no
CHR-ROM receives writable CHR-RAM. PRG-RAM, battery-backed state, four-screen
metadata, and nametable mirroring are represented where the header and mapper
support them.

Mapper 9 (MMC2) and mapper 10 (MMC4) support CHR bank switching through PPU
address latches, along with their mapper-controlled PRG and nametable behavior.

Mapper 66 selects 32 KiB PRG and 8 KiB CHR banks. Mapper 69 implements FME-7
banking and CPU-cycle IRQ counting without the Sunsoft 5B audio extension.
Mapper 79 selects 32 KiB PRG and 8 KiB CHR banks. Mapper 71 uses a UxROM-like
layout with a switchable lower 16 KiB PRG bank and a fixed upper 16 KiB bank.
Mapper 87 selects its CHR bank through writes in the `$6000-$7FFF` range and
does not expose PRG-RAM through that range.

## ROM verification evidence

The automated P2 harness is `cl-nes/rom-suite`. It consumes fixed, flake-only
inputs for `christopherpow/nes-test-roms` and `100thCoin/AccuracyCoin`; ROM
bytes are not committed to this repository. The contract table is in
`t/rom-suite/protocols.lisp` and uses the blargg `$6000` signature/status
protocol, framebuffer hashes, and AccuracyCoin's `$0400-$04FF` result RAM.
Each row has a bounded frame limit and a ratchet state. A passing `:pass` row
must remain passing, while an unexpectedly passing `:known-fail` row fails the
check and requires its recorded baseline to be updated.

The measured baseline is recorded in the same table. The CI profile uses short
frame limits for known failures so the check stays within the five-minute
budget; the table's failure text preserves the first diagnostic observed. The
full AccuracyCoin run remains a bounded manual run because the current core
does not complete all 146 result cells within the CI budget.

External validation artifacts are kept outside the checkout. Their records
include the source revision, per-file SHA-256, and available license or
permission metadata; ROM binaries are not part of the repository.

For the current validation run, each valid manifest entry was executed in a
fresh emulator process with a bounded wall-clock limit. Every valid iNES or
NES 2.0 entry in the public test-ROM manifest reached 10 frames, covering the
mapper numbers represented by that manifest. A separate homebrew corpus reached
60 frames per entry. A malformed ROM was reported as `invalid` and excluded
from the valid ROM pass. Focused mapper contracts also cover the discrete
banking paths for mappers 66, 71, and 87; those contracts are separate from the
ROM-corpus evidence above.

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

Mapper 4 defaults to the MMC3 IRQ reload behavior. NES 2.0 submapper 1 selects
MMC6 behavior and submapper 2 selects the alternate MMC3 behavior. Some ROMs need the
zero-counter reload suppression behavior shared by MMC6-compatible revisions;
select it explicitly with mapper4-variant :mmc6 or :mmc3-alt. The header does
not select the alternate behavior when an explicit mapper4-variant argument is
provided.

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

The headless output API converts framebuffers to RGB octets, writes binary P6
PPM images, and writes unsigned 8-bit mono PCM samples as RIFF/WAVE files. It
does not open an audio output device.

Controllers implement the standard eight-button mask and serial strobe/shift
behavior. OAM DMA is routed through the CPU bus and contributes its stall
cycles to instruction stepping.

## Unsupported behavior

Unsupported mapper numbers, unsupported ROM header features, malformed ROM
data, and unsupported CPU opcodes signal conditions. The project does not
provide a graphical window, audio output device, or a promise that every NES
timing edge is reproduced.
