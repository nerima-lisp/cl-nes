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

The table is the ROM-by-ROM verdict: `:pass` rows are required to pass, and
`:known-fail` rows are expected to fail until their recorded limitation is
fixed. The current table contains 100 bounded ROM contracts. Its category
counts are derived from the `:category` and `:state` fields in
`t/rom-suite/protocols.lisp`:

| category | expected pass | expected known-fail | total |
| --- | ---: | ---: | ---: |
| CPU | 28 | 10 | 38 |
| PPU | 20 | 15 | 35 |
| APU | 8 | 6 | 14 |
| DMA | 0 | 2 | 2 |
| mapper | 8 | 3 | 11 |
| total | 64 | 37 | 101 |

The per-ROM rows in `*rom-contract-data*` are the source of truth for the
individual verdicts. They contain the id, category, ROM path, protocol, frame
bound, ratchet state, and failure diagnostic; there is no second compatibility
list. The same table is checked first by `run-rom-suite.lisp`. In the current
measured run, all 200 declarative table checks passed and `sprite-hit-11`
completed within its 360 frame bound.

AccuracyCoin is a separate contract with 146 expected result cells and a
1200-frame bound. Its `:known-fail` state is enforced by the same ratchet. The
runner reads the result RAM at `$0400-$04FF`, classifies each cell as pass,
fail, skipped, or running, and prints pass/fail counts followed by counts for
the categories declared in `*accuracy-coin-item-specs*`. The category names
currently include CPU behavior, CPU instructions, unofficial opcode groups,
CPU interrupts, DMA, APU, CPU behavior 2, PPU, PPU vblank, sprite, PPU misc,
advanced background, and advanced sprite. The current run measured 86 passing
cells, 58 failing cells, and no skipped or running cells. Category counts were
CPU behavior 8, CPU instructions 6, unofficial SLO 7, unofficial RLA 7,
unofficial SRE 7, unofficial RRA 7, unofficial AX 10, unofficial DCP 7,
unofficial ISC 7, unofficial SH 1, unofficial immediate 7, CPU interrupts 1,
DMA 1, APU 5, CPU behavior 2 3, and PPU 2. PPU vblank, sprite, PPU misc,
advanced background, and advanced sprite each measured 0.

To reproduce the complete harness with legally obtained ROM inputs, use the
flake check:

~~~sh
nix build .#checks.aarch64-darwin.rom-suite --print-build-logs
~~~

For a direct run, provide the same four inputs used by the flake:

~~~sh
CL_NES_TEST_ROMS=/path/to/nes-test-roms \
CL_NES_ACCURACY_COIN=/path/to/AccuracyCoin.nes \
CL_NES_NESTEST_ROM=/path/to/nestest.nes \
CL_NES_NESTEST_LOG=/path/to/nestest.log \
sbcl --noinform --non-interactive --load run-rom-suite.lisp --quit
~~~

The harness prints one result for every ROM reached, AccuracyCoin category
counts when that contract is reached, and the nestest trace result. A `:pass`
row failing is a regression; a `:known-fail` row passing requires updating the
table and its diagnostic. ROM bytes and generated output remain outside the
checkout.

External validation artifacts are kept outside the checkout. Their records
include the source revision, per-file SHA-256, and available license or
permission metadata; ROM binaries are not part of the repository.

The current measured run establishes the declarative table checks,
`sprite-hit-11`, and the AccuracyCoin counts above. It does not establish a
fully passing ROM suite, complete nestest results, reference framebuffer
output, interactive controls, audio fidelity, exact cycle traces, or
compatibility with every NES game. PPU scanline/dot fields in nestest remain
excluded because the public core API does not expose them.

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

PPU rendering follows the dot pipeline for background fetches, sprite
evaluation, sprite-zero hits, and framebuffer composition. PPU and mapper
timing is still intentionally coarse in some compatibility-sensitive paths.
nes-step/k is therefore an instruction-oriented headless API, not a
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

The current known-fail set is concentrated in unofficial CPU opcode coverage,
interrupt/reset edge timing, PPU sprite-hit and power-up behavior, APU
length/IRQ/DMC timing, DMA ordering, and selected MMC3 scanline timing. The
AccuracyCoin result cells are reported by the ROM suite and remain the
authoritative measured record for precision work; they are not inferred from
the category counts above.
