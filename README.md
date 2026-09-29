# cl-nes

cl-nes is a headless Nintendo Entertainment System core written in Common
Lisp. Its only runtime dependency is [cl-host-kit](https://github.com/nerima-lisp/cl-host-kit),
used for cartridge ROM file reads. It supports iNES cartridges, the
supported subset of NES 2.0, mappers 0, 1, 2, 3, 4, 5, 7, 9, 10, 11, 22, 28,
34, 66, 71, and 87, and headless CPU, PPU, controller, and APU execution.

## Quick Start

~~~lisp
(require :asdf)
(load "cl-nes.asd")
(asdf:load-system :cl-nes)

(let* ((cartridge (cl-nes:load-cartridge "game.nes"))
       (nes (cl-nes:make-nes :cartridge cartridge)))
  (cl-nes:nes-run-frame/k
   nes
   (lambda (framebuffer)
     (format t "framebuffer elements: ~D~%" (length framebuffer)))))
~~~

The continuation receives the headless 256x240 framebuffer. The core does not
open a window or an audio device; callers choose how to display or encode the
result. `nes-write-ppm` and `nes-write-wav` provide portable file output for
framebuffers and unsigned 8-bit audio samples.

## Install

Use the checkout directly with ASDF. A standalone SBCL process can load the
system with:

~~~sh
sbcl --non-interactive \
  --eval '(require :asdf)' \
  --load cl-nes.asd \
  --eval '(asdf:load-system :cl-nes)' \
  --quit
~~~

The pinned development environment is available with nix develop.

## Documentation

- [Documentation index](docs/src/index.md)
- [Getting started](docs/src/getting-started.md)
- [API reference](docs/src/reference/api.md)
- [Compatibility](docs/src/reference/compatibility.md)

## Development

From the pinned development environment, run the canonical cl-weave suite:

~~~sh
nix develop
sbcl --noinform --non-interactive --load run-tests.lisp --quit
sbcl --noinform --non-interactive --load run-coverage.lisp --quit
nix flake check
~~~

The cl-weave suite includes generated property contracts for controller
serialization, CHR writes, PPU address wrapping, and NROM reads.

`run-tests.lisp` also accepts focused cl-weave selection through environment
variables. The values below keep the full-suite default when unset:

~~~sh
CL_NES_TEST_NAME_FILTER=mmc1 \
CL_NES_TEST_LOCATION_FILTER=t/coverage-mapper-contracts.lisp \
CL_NES_TEST_PATH_FILTER='mapper contracts > mmc1 updates mirroring and chr banks' \
CL_NES_TEST_INCLUDE_TAGS=mapper,contracts \
CL_NES_TEST_REPORTER=spec \
CL_NES_TEST_SEED=20260813 \
CL_NES_TEST_TIMEOUT_MS=1000 \
CL_NES_TEST_MAX_WORKERS=1 \
sbcl --noinform --non-interactive --load run-tests.lisp --quit
~~~

`CL_NES_TEST_LOCATION_FILTER` and `CL_NES_TEST_PATH_FILTER` accept
comma-separated lists. Test paths use cl-weave's `suite > nested suite > test`
form.

`nix flake check` also enforces the coverage ratchet and builds the MkDocs
manual with strict navigation checks. The long-term coverage target is 100%
expression and branch coverage.

The flake currently supports x86_64-linux and aarch64-darwin. aarch64-linux
and x86_64-darwin are left out; neither was covered by this repository's own
tooling in a way it could verify.

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
state directory, and writes them back on exit. Without `--state-directory`,
state is stored below the XDG data directory in `cl-nes/`. Save states are
stored per ROM in ten slots. Press a number key (0 through 9) to select a
slot, F5 to save it, and F7 to load it. P pauses, R resets, Z/X are B/A,
Shift/Enter are Select/Start, and the arrow keys are the D-pad. A connected
GLFW gamepad supplies the first two controller ports. `render` writes numbered PPM or
PNG frames. `rom-test` runs the bounded diagnostic protocol and reports its
status. These commands do not download or distribute ROM files; use a
self-created, homebrew, public-domain, or otherwise legally obtained corpus.
A bounded result is a smoke check, not a claim of universal ROM compatibility.

## Contributing

Keep implementation, tests, and public documentation aligned. Changes to
cartridge formats, mappers, timing, or exported symbols should include the
corresponding tests and reference-page updates.

## Support

When reporting a problem, include the SBCL version, the command used, the ROM
format and mapper when relevant, and the smallest reproducible input.

## License

Released under the MIT License. See [LICENSE](LICENSE).
