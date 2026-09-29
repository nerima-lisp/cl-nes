# Roadmap

This page records boundaries that may guide future work. It is not a release
schedule.

## Compatibility depth

- Keep the dot-level PPU pipeline aligned with hardware timing as new
  reference cases expose edge behavior; the core already advances rendering,
  fetches, sprite evaluation, vblank/NMI, and mapper A12 timing per dot.
- Refine mapper timing and IRQ edge behavior as additional test ROMs require.
- Expand cartridge format and mapper coverage while preserving explicit
  unsupported-mapper conditions.

## Verification and release gates

- Before any change is integrated into `main`, run the complete cl-weave test
  system and the complete ROM suite. The ROM-suite gate must include
  AccuracyCoin and honor its declared ratchet state; a known-fail result is
  not permission to omit the ROM or silently treat it as passed.

## Host integration

- Keep the core independent of windowing and audio-device libraries.
- Improve examples for consuming framebuffer and APU sample data.
- Make ROM-suite and diagnostic output easier to integrate into external test
  harnesses.

## Project tooling

- Keep the API reference synchronized with exported symbols.
- Add documentation-build verification to project automation when the build
  environment provides the required MkDocs tooling.
- Preserve external manifest, hash, license, and TSV evidence when extending
  mapper or test-ROM coverage.
- After cl-weave v1.4.0 is released and available to the project, migrate the
  test configuration and suite selection to cl-weave's allowlist model. Keep
  the allowlist explicit, reviewable, and non-empty, and retain the existing
  no-tests failure behavior; do not broaden selection or bypass the full-test
  and ROM-suite gates during the migration.
- Add reference-frame, input, and audio assertions beyond bounded frame
  progression.
