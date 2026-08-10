# Roadmap

This page records boundaries that may guide future work. It is not a release
schedule.

## Compatibility depth

- Refine PPU timing in paths that are currently intentionally coarse.
- Refine mapper timing and IRQ edge behavior as additional test ROMs require.
- Expand cartridge format and mapper coverage while preserving explicit
  unsupported-mapper conditions.

## Host integration

- Keep the core independent of windowing and audio-device libraries.
- Improve examples for consuming framebuffer and APU sample data.
- Make ROM-suite and diagnostic output easier to integrate into external test
  harnesses.

## Project tooling

- Keep the API reference synchronized with exported symbols.
- Add documentation-build verification to project automation when the build
  environment provides the required MkDocs tooling.
- Record compatibility results for each newly supported mapper or test-ROM
  family.
