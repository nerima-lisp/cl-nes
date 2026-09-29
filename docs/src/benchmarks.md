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
