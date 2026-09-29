# Benchmarks

The measurements below use SBCL 2.6.6 on aarch64-darwin. Wall-clock values
are diagnostic only because the host was shared.

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

`play` opens the GLFW/OpenGL window, restores battery-backed saves from the
state directory, and writes dirty saves periodically and on exit. `render`
writes numbered PPM or PNG frames. `rom-test` runs the bounded diagnostic
protocol and reports its status.

## Emulator frame time

Measured with `benchmark/run-benchmarks.lisp` on the same shared aarch64-darwin
host, using SBCL 2.6.6, rendering enabled (`PPUMASK=$18`), two 60-frame warmup
batches, and ten 60-frame samples. The load average was `{21.48 21.54 24.02}`
at the end of the run.

| workload | median | minimum | maximum |
| --- | ---: | ---: | ---: |
| NROM rendering | 17.589 ms/frame | 17.317 ms/frame | 20.681 ms/frame |
| MMC3 bank switching and scanline IRQ | 20.647 ms/frame | 17.271 ms/frame | 30.856 ms/frame |

The measurements are above the provisional 8.3 ms/frame target on this shared
host. The CPU profile's common leading locations were `%ppu-background-fetch!`,
`ppu-tick!`, `%ppu-clock-pipeline!`, and `ppu-read-vram`.
