# Stream handoff

## 1. Completed

- `5ee9db3`: MMC3 revision A variant behavior; the revision-A ROM passes with `:mmc3-rev-a`.
- `5e3b5b7` (rebased as `764ac53`): MMC1 CHR1 bit 4 WRAM gating tied to PPU A12 state.
- `764ac53` is included in `main` through the required compare-and-swap update.
- Existing full test suite was verified at `737 passed, 0 failed, 0 errored`.
- The MMC1 same-address write regression test and the next-instruction write test are in main.

## 2. Remaining

- `mmc3_irq_tests/3.A12_clocking.nes`: result code 6 remains.
- `mmc3_irq_tests/4.Scanline_timing.nes`: result code 4 remains.
- `mmc3_test_2/4-scanline_timing.nes`: test #3 remains failing.
- MMC1_A12 automated confirmation is waiting for the P2b probe changes to land in `main`.

### MMC3 dot phase experiments

- Sprite A12 phase dot 257: `mmc3_test_2/2-details` regressed to test #8; scanline timing failed test #2.
- Sprite A12 phase dot 265: `mmc3_test_2/2-details` regressed to test #8; scanline timing failed test #3.
- Sprite A12 phase dot 260 with render filter 6: `mmc3_test_2/2-details` passed, but scanline timing failed test #2.
- Sprite A12 phase dot 262 with render filter 6: `mmc3_test_2/2-details` passed, but scanline timing failed test #3.
- Sprite A12 phase dot 266: `mmc3_test_2/2-details` passed, but scanline timing remained test #3; `mmc3_irq_tests/4.Scanline_timing` remained code 4.

The background phase experiments moving dot 10 to dot 5 and dot 330 to dot 325 did not improve the ROM results and were reverted. The working tree uses the original dot-10/dot-330 background phase and dot-266 sprite phase.

## 3. Next step

Wait for the P2b probe changes to reach `main`, then rebase the stream and run the MMC1_A12 probe on the flake ROM. For MMC3, instrument the CPU-visible `$2006/$2007` A12 transition and the render-dot notification together, preserving the existing 241-clock detail contract while locating the IRQ polling boundary between the dot-260 and dot-262 outcomes.

## 4. Traps

- Do not treat the numeric result code as a generic failure code. In `mmc3_irq_tests`, code 6 identifies the `$2007` write A12-clock test; code 4 identifies the scanline-1 timing test.
- A global filter change from 24 to 8 dots can make `mmc3_test_2/2-details` pass or fail depending on the render phase, but it does not by itself fix A12_clocking. Keep CPU-visible `$2006/$2007` filtering separate from render-dot phase experiments.
- Moving the sprite phase too early can add extra clocks and fail the 241-clocks-per-frame detail assertion.
- `main` may advance from other streams. Before any future CAS update, read `git rev-parse main`, ensure it is an ancestor of HEAD, and use the exact required update-ref command.
- The audio API errors belong to the APU stream and are out of scope here.

## 5. Related files

- `src/ppu/ppu-timing.lisp`: `%ppu-a12-high-p`, `%ppu-clock-render-a12!`, and per-dot A12 notification.
- `src/ppu/ppu-registers.lisp`: CPU-visible `$2006/$2007` A12 notification paths.
- `src/ppu/ppu.lisp`: `%ppu-clock-address-a12!`.
- `src/cartridge/mappers/cartridge-mapper4-control.lisp`: MMC3 A12 filter and IRQ counter clocking.
- `src/cartridge/cartridge-state.lisp`: `+mapper4-a12-low-filter-cycles+`.
- `src/cartridge/mappers/cartridge-mapper1.lisp`: MMC1 WRAM/A12 gating.
- `t/rom-suite/protocols.lisp`: current ROM contract rows.
- `/nix/store/rw68jiwj3asrkkxrla5k6c6k17jcgi07-source/mmc3_irq_tests/readme.txt`: ROM test meanings.
- `/nix/store/rw68jiwj3asrkkxrla5k6c6k17jcgi07-source/mmc3_test_2/source/4-scanline_timing.s`: scanline timing thresholds.
- `/nix/store/rw68jiwj3asrkkxrla5k6c6k17jcgi07-source/MMC1_A12/mmc1_a12.asm`: MMC1 WRAM/A12 ROM behavior.
