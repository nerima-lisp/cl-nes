# Benchmarks

The measurements below use SBCL 2.6.6 on aarch64-darwin. Wall-clock values
are diagnostic only because the host was shared. The frame measurements use
the synthetic cartridges in `benchmark/run-benchmarks.lisp`, not external ROMs.

## Flake check timing

The latest checks were run on the pinned aarch64-darwin host. The measured
times were 48 s in the test check phase, 63 s in coverage, 8.60 s for frontend
tests, 12.95 s for docs, and 6.43 s for the recursive paredit scan. The ROM
suite took 499.09 s real and 481 s in its
check phase, and reached AccuracyCoin. The benchmark app took 24.63 s real;
its frame medians are recorded below.

The combined `nix flake check` gate remains above the provisional five-minute
target because of the bounded ROM suite and its AccuracyCoin run.

To repeat the measurement, use `/usr/bin/time -p nix flake check
--print-build-logs` and retain the per-check `checkPhase completed` lines.

## Frontend startup

On aarch64-darwin, the built `cl-nes --version` executable completed in 0.06 s
real time (`/usr/bin/time -p`, one cold process invocation), below the 100 ms
startup target. This measurement includes image startup and argument handling,
but does not open a window or audio device.

The frontend executable is `cl-nes`. It exposes the interactive player,
offline rendering, and bounded ROM diagnostics as subcommands. `--version`
prints the frontend version and exits:

~~~sh
cl-nes --version
cl-nes play ROM.nes [--state-directory PATH] [--scale INTEGER]
cl-nes render ROM.nes [--frames INTEGER] [--prefix PREFIX] [--format ppm|png]
cl-nes rom-test ROM.nes [--max-frames INTEGER] [--mapper4-variant mmc3|mmc6|mmc3-alt]
~~~

`play` opens the GLFW/OpenGL window and restores battery-backed saves from the
state directory. The CLI default is the current directory; state is then
isolated below `cl-nes/<ROM-SHA256>/`, with ten save-state slots (`0` through
`9`), F5/F7 save/load keys, and P/R pause/reset keys. Z/X are B/A, Shift/Enter
are Select/Start, and the arrow keys are the D-pad. `render` writes numbered
256x240 PPM or PNG frames. `rom-test` runs the bounded `$6000` diagnostic
protocol and supports `mmc3`, `mmc6`, or `mmc3-alt` for mapper 4.

## Emulator frame time

Measured with `nix run .#bench` on the shared aarch64-darwin host, using SBCL
2.6.6, rendering enabled (`PPUMASK=$18`), two 60-frame warmup batches, and ten
60-frame samples. Each reported time is the median, minimum, or maximum of the
ten samples, normalized to one frame.

| workload | median | minimum | maximum |
| --- | ---: | ---: | ---: |
| NROM rendering | 12.276 ms/frame | 12.065 ms/frame | 12.594 ms/frame |
| MMC3 bank switching and scanline IRQ | 13.277 ms/frame | 13.057 ms/frame | 13.519 ms/frame |

Both workloads reported 0.000 bytes consed per frame for the median, minimum,
and maximum allocation samples.

The measurements are above the provisional 8.3 ms/frame target on this shared
host. The CPU profile's common leading locations were `%ppu-background-fetch!`,
`ppu-tick!`, `%ppu-clock-pipeline!`, and `ppu-read-vram`.
