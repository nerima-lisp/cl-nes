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
protocol, runtime framebuffer hashes, and AccuracyCoin's `$0400-$04FF` result
RAM. These hashes are diagnostics of the emulator's output; they are not
golden or reference-image hashes.
Each row has a bounded frame limit and a ratchet state. A passing `:pass` row
must remain passing, while an unexpectedly passing `:known-fail` row fails the
check and requires its recorded baseline to be updated.

The table is the ROM-by-ROM verdict: `:pass` rows are required to pass, and
`:known-fail` rows are expected to fail until their recorded limitation is
fixed. Its category and state counts are derived from the `:category` and
`:state` fields in `t/rom-suite/protocols.lisp`; that source table is
authoritative and this page intentionally does not duplicate its counts.

The per-ROM rows in `*rom-contract-data*` are the source of truth for the
individual verdicts. They contain the id, category, ROM path, protocol, frame
bound, ratchet state, and failure diagnostic; there is no second compatibility
list. The same table is checked first by `run-rom-suite.lisp`.

AccuracyCoin is a separate contract whose result-cell definition and frame
bound are in `*accuracy-coin-contract*`. Its `:known-fail` state is enforced
by the same ratchet. The runner reads the result RAM at `$0400-$04FF`,
classifies each cell as pass, fail, skipped, or running, and prints counts for
the categories declared in `*accuracy-coin-item-specs*`. Those declarations
and the measured output are authoritative; this page intentionally does not
duplicate their counts.

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
MMC6 behavior and submapper 2 selects the alternate MMC3 behavior. The core
also accepts the explicit `:mmc3-rev-a` variant for the MMC3 revision-A IRQ
contract. Some ROMs need the zero-counter reload suppression behavior shared
by MMC6-compatible revisions; select it explicitly with mapper4-variant
`:mmc3-rev-a`, `:mmc6`, or `:mmc3-alt`. The header does not select the
alternate behavior when an explicit mapper4-variant argument is provided.

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

## Homebrew ROM compatibility corpus

The new compatibility check uses a fixed, non-commercial corpus from the
`retrobrews/nes-games` project at commit
`d20061bf9917e8bb8b947d4dba8c59372f5762a0`. ROM files are fetched by the flake
input and are not committed to this repository. The complete provenance table
is `t/compat/corpus.lisp`; it records the source URL, SHA-256, mapper, and the
license or distribution-permission evidence recorded by the upstream project.

The corpus contains 71 ROMs and covers mappers 0, 1, 2, 3, 4, 7, 28, 30, 66,
and 113. The mapper-focused portion has 8 MMC1, 6 UxROM, 6 CNROM, 7 MMC3,
and 4 AxROM ROMs; four AxROM binaries were found in the audited licensed
homebrew sources. Each entry has a concrete license-source URL and a quoted
license or distribution-permission note. The Retrobrews entries use the
project README's per-ROM distribution record; explicit metadata is retained
as MIT, GPL/LGPL, zlib, GNU All-Permissive, or the exact Creative Commons
variant. Non-commercial and share-alike restrictions are not relabeled as
plain CC-BY.

For every entry, the check runs a bounded number of frames twice with the same initial state.
It writes a representative PNG image at the final frame and reports exceptions,
unsupported mappers, frame-boundary CPU progress, framebuffer change, non-zero
audio samples, and whether final framebuffer hashes match across the two runs.
The final-frame hash comparison checks deterministic reruns of the same ROM;
it is not a comparison with an external golden framebuffer.

Results are written to `compat-results.tsv` and images to the configured
compatibility artifact directory. A `pass` result is the ratchet baseline;
`stopped`, `static`, `silent`, `crash`, and `unsupported-mapper` remain visible
as compatibility findings. The checked-in ratchet is
`t/compat/baseline.tsv`; it records the expected status and mapper for every
corpus entry. The check fails for crashes or nondeterministic output. Generated
images and ROM files are not committed.
