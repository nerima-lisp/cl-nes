# Changelog

## Unreleased

### Breaking changes

- Save-state format version 3 records the sampled CPU IRQ input, the CPU's
  internal data bus latch, PPU sprite-evaluation phase and OAM bus latches,
  OAM2 address, data, frozen state, write event, pending OAM corruption rows,
  current APU/DMA transfer state, APU frame IRQ phase, deferred `$4015`
  status-read clear, the absolute NES master-clock position, and the PPU phase
  offset. DMC DMA state includes its phase offset, request-start APU phase, and
  a pending APU-phase carry applied at the next loop reload. Loading rejects
  incompatible layouts, so version 2 states and earlier version 3 states are
  not portable to this release (`d312bab`, `0e39583`, `69131ed`, `9744984`,
  `9b6dee3`, `1a44e38`, `e74bbf6`, `baba7f4`, `97e8ae2`, `306e581`,
  `8676428`, `e6ae3fd`, `e5d8f05`, `f209615`, `a01d067`, `108e9ab`,
  `a5c8618`, `e8673c8`, `3219946`).

### Compatibility and cartridge support

- Added mapper 30 and 113 support, including mapper 30 four-screen VRAM routing,
  and corrected UxROM bank selection and submapper 2 bus conflicts
  (`c7c16cb`, `4dec383`, `e6867d9`, `dc75096`).
- Aligned ROM compatibility behavior with emulated reset delays, frame-scheduled
  input, and APU readiness-based silence classification
  (`222eb1d`, `d4bce49`, `9164348`).

### Emulation fixes

- Corrected CPU interrupt polling across DMA and DMC stalls, reset timing,
  unstable indexed stores, and internal bus reads; preserved polling through
  interrupt tests and skipped inactive NMI-vector hooks
  (`384a83b`, `ce5598f`, `4a91a47`, `d312baba`, `b5f8be7`, `0dadf59`,
  `81fbf63`, `0e39583`, `1797642`, `38e9c20`).
- Corrected AccuracyCoin's one-cycle implicit DMC DMA abort timing on top of
  `60df2ea`.
- Improved sprite evaluation and timing, including rendering-disabled cases and
  sprite-zero detection (`69131ed`, `e74bbf6`, `baba7f4`, `eaf096b`,
  `ec66b08`, `361957e`, `0ceb9e0`, `4c83cce`, `8676428`, `e6ae3fd`,
  `e5d8f05`, `9fe796c`, `d75f325`).
- Corrected `$2004` read timing, sprite overflow completion, and OAMADDR
  alignment (`55e1dee`, `3219946`).
- Calibrated the early PPU OAM corruption cutoff to dots 0–10, including
  AccuracyCoin Test 2 results when rendering is disabled at dots 7, 9, and 10.
  Dots 11–63 remain unmodeled because hardware-tested blargg
  `sprite_overflow_tests` Test 5 shows no observable corruption effect when
  rendering is disabled at dot 16. PPU revision and CPU/PPU phase also affect
  corruption and are not modeled, so this calibration is not a complete
  hardware model (`108e9ab`, `1b0d9c5`).
- Corrected PPU register and rendering behavior, including the measured
  power-up palette, vblank and buffered reads, split `$2002` status sampling,
  background fetch timing, ALE/PPUDATA overlap, and MMC3 scanline timing
  (`80e2486`, `64e7243`,
  `2e859a2`, `9744984`, `4fa095b`, `8edba64`, `a2de74f`, `97e8ae2`,
  `cc24ccf`, `0654cfd`, `9340de4`).
- When a rendering-time `$2006` write changes the address high bits, the next
  background pattern read uses those live high bits with the low byte captured
  at the fetch (`306e581`).
- Aligned APU frame IRQ and reset boundaries, length-counter timing, and DMC
  sample status (`9b6dee3`, `f857372`, `48df297`, `25eac88`, `4ed6879`,
  `d4359c9`).
- Modeled staged DMA transfers and DMC register conflicts, delayed DMC request
  timing and aligned APU-phase reloads, corrected halted read retry and DMA IRQ
  polling, decoded held `$4015` reads during OAM GET, fixed OAM DMA I/O source
  reads, and coalesced repeated OAM DMA writes (`1a44e38`, `daf5e80`,
  `05742ab`, `1797642`, `b0cda88`, `f209615`, `a5c8618`, `e8673c8`,
  `f1ae62b`, `29aea20`).

### CI and test harness

- Split the ROM suite into bounded shards, moved allocation and frame-time
  scaling checks into the heavy tier, and classified allocation timeouts
  (`1fa99fa`, `f4ba72b`, `4bbf4fb`, `d4ec27f`). Derived CPU timeouts from
  measured frame costs (`388dfb5`, `a7a8aae`, `222b072`).
- Improved ROM result reporting and failure gates by aggregating shard errors,
  reporting ratchet losses, and failing known contract failures
  (`b2f3686`, `114accd`, `f27c06e`, `d6b42ba`).
- Recorded per-ROM progress and compatibility results, drove ROM inputs from a
  frame schedule, and updated AccuracyCoin and other ROM accuracy ratchets
  (`9be7b22`, `73756d5`,
  `eceea2a`, `8f9fa75`, `d8025d5`, `2a7a829`, `a797607`, `1fc1917`,
  `838f0a3`, `2ebe511`).
- Updated CI timeout and shard gates and pinned gates to x86_64 Linux
  (`a4a8535`, `9451a79`).
- Pinned the paredit CLI output in the primary cache and reduced delays for
  stalled Nix downloads (`ed5209b`, `454ee20`).
- Fixed coverage runner dependencies and path ordering, validated ROM suite
  worker counts, and prepared the paredit CLI cache for CI inspection
  (`f7f4a32`, `89b4f9a`, `1231014`, `8d47e9e`, `427b6c6`).

## v0.3.0

### Breaking changes

- Save-state loading now rejects incompatible format versions. Save states
  produced with an incompatible version are not portable to this release
  (`b538c4a`).

### Compatibility and cartridge support

- Corrected mapper bank access and MMC6 read protection (`05b8c90`).
- Preserved NES 2.0 CHR-ROM sizes during ROM parsing (`0def7aa`).
- Added mapper 34 NINA-001 banking and completed mapper 79 and 87 bank
  handling (`ac8e317`, `a9a5ab3`, `176dd3c`).
- Corrected mapper 69 IRQ control and counter-underflow handling
  (`3c59cd8`, `575d38f`).
- Preserved MMC6-compatible legacy result access for ROM compatibility
  (`33356a1`, `262e179`, `59eff62`).

### Audio and timing

- Corrected APU length-counter reload timing and retained triangle DAC and DMC
  output state across the relevant halted or disabled states
  (`0bfb19b`, `6a00c48`, `20583e3`, `7af9c35`).
- Avoided duplicate audio overrun accounting (`e6b2c03`).

### Frontend and persistence

- Improved frontend cleanup for failed audio or startup paths and released
  OpenGL framebuffer resources (`27d799e`, `321e065`, `8fbd3ff`, `ffb7fc7`).
- Made atomic persistence saves synchronized and made invalid battery files
  recoverable (`ddb8fe8`, `74c988a`).
- Save-state decoding now validates section structure and collection bounds
  before applying decoded state (`4eb16e7`, `97cd53b`, `f39cfd0`).

### Verification and tooling

- Split the ROM suite into per-shard flake checks so compatibility coverage can
  run through the same declarative contracts in parallel. The checks are
  `rom-suite-cpu`, `rom-suite-ppu`, `rom-suite-apu-test`, `rom-suite-apu-dmc`,
  `rom-suite-apu-timing`, `rom-suite-dma`, and `rom-suite-mapper`; the mapper
  shard retains the AccuracyCoin and nestest runs. The separate
  round-robin `compat-shard-*` checks exercise the licensed homebrew corpus and
  its checked-in status ratchet.
- Expanded CPU opcode semantics, APU, cartridge, mapper, savestate, frontend,
  and DMA contract coverage (`461d89e`, `6cdc68d`, `b7ef63f`, `593fe22`,
  `3802835`, `2829d1c`).
- Added benchmark and coverage maintenance, including a benchmark entry point
  and corrected frontend and coverage runners (`adf176d`, `a55282b`,
  `2d821a2`, `3b74ce4`).
