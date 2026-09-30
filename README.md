# cl-nes

cl-nes is a headless Nintendo Entertainment System core written in Common
Lisp. Its only runtime dependency is [cl-host-kit](https://github.com/nerima-lisp/cl-host-kit),
used for cartridge ROM file reads. It supports iNES cartridges, the
supported subset of NES 2.0, mappers 0, 1, 2, 3, 4, 5, 7, 9, 10, 11, 22, 28,
34, 66, 69, 71, 79, and 87, and headless CPU, PPU, controller, and APU
execution.

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

The pinned development environment is available with `nix develop`. The flake
also builds the `cl-nes` frontend:

~~~sh
nix run .# -- --version
~~~

For a local checkout, the ASDF form above is sufficient for the headless core.
The interactive frontend additionally needs the GLFW/OpenGL and SDL runtime
libraries supplied by the flake.

The frontend executable is produced by the flake; the headless core can be
used directly from ASDF without opening a window or audio device.

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

Before updating `main`, run both the complete cl-weave suite and the complete
ROM suite with the pinned `nes-test-roms`, AccuracyCoin, nestest ROM, and
nestest log inputs. Unit tests alone are not the integration gate.

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

`play` opens the GLFW/OpenGL window and paces audio through SDL. The CLI
default for `--state-directory` is the current directory, so pass a directory
outside the checkout when desired. State is stored below
`cl-nes/<ROM-SHA256>/`: battery-backed cartridges use `battery.sav`, and save
states use ten slots named `slot-0.state` through `slot-9.state`. Battery data
is restored at startup and written periodically and on exit. `--scale` defaults
to 3.

The default keyboard mapping is:

| NES input | Key |
| --- | --- |
| A / B | X / Z |
| Select / Start | Shift / Enter |
| D-pad | Arrow keys |
| Select save slot | 0 through 9 |
| Save / load state | F5 / F7 |
| Pause / reset | P / R |

A connected GLFW gamepad supplies the first two controller ports. `render`
writes numbered 256x240 PPM or PNG frames; `--frames` defaults to 1,
`--prefix` to `frame`, and `--format` to `ppm`. `rom-test` runs the bounded
`$6000` diagnostic protocol; `--max-frames` defaults to 360. `rom-test` can
select `mmc3`, `mmc6`, or `mmc3-alt` explicitly for mapper 4.

The implemented mapper set is 0, 1, 2, 3, 4, 5, 7, 9, 10, 11, 22, 28, 34,
66, 69, 71, 79, and 87. Mapper 4 defaults to MMC3 behavior; NES 2.0 submapper
1 selects MMC6 and submapper 2 selects the alternate MMC3 behavior unless an
explicit frontend option is supplied.

Known limitations include intentionally coarse timing in selected PPU and
mapper paths, incomplete exact CPU/PPU trace compatibility, selected APU/DMA
edge cases, no Sunsoft 5B audio extension for mapper 69, and no built-in
window or audio device in the core. Unsupported mapper numbers, unsupported
header features, malformed ROMs, and unsupported CPU opcodes signal
conditions. `rom-test` is a bounded startup/protocol smoke check, not a full
instruction, timing, audio, mapper, or game-compatibility certification. The
commands do not download or distribute ROM files; use a legally obtained
corpus. See the
[compatibility reference](docs/src/reference/compatibility.md) for the
ratcheted ROM results.

## Contributing

Keep implementation, tests, and public documentation aligned. Changes to
cartridge formats, mappers, timing, or exported symbols should include the
corresponding tests and reference-page updates.

## Support

When reporting a problem, include the SBCL version, the command used, the ROM
format and mapper when relevant, and the smallest reproducible input.

## License

Released under the MIT License. See [LICENSE](LICENSE).
