# cl-nes

cl-nes is a headless Nintendo Entertainment System core written in Common
Lisp. It has no third-party runtime dependency and supports iNES cartridges,
the supported subset of NES 2.0, mappers 0, 1, 2, 3, 4, 5, 7, 11, 22, 28, and
34, and headless CPU, PPU, controller, and APU execution.

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
result.

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

`nix flake check` also enforces the coverage ratchet and builds the MkDocs
manual with strict navigation checks. The long-term coverage target is 100%
expression and branch coverage.

The flake currently supports aarch64-darwin, aarch64-linux, and x86_64-linux;
the pinned nixpkgs release no longer supports x86_64-darwin.

run-nes.lisp writes rendered frames as binary PPM images:

~~~sh
sbcl --script run-nes.lisp ROM.nes [frames] [output-prefix]
~~~

run-rom-suite.lisp executes one ROM and emits TSV diagnostics. Mapper 4
accepts an explicit mmc3, mmc6, or mmc3-alt variant:

~~~sh
sbcl --script run-rom-suite.lisp ROM.nes [max-steps] [mmc3|mmc6|mmc3-alt]
~~~

## Contributing

Keep implementation, tests, and public documentation aligned. Changes to
cartridge formats, mappers, timing, or exported symbols should include the
corresponding tests and reference-page updates.

## Support

When reporting a problem, include the SBCL version, the command used, the ROM
format and mapper when relevant, and the smallest reproducible input.

## License

Released under the MIT License. See [LICENSE](LICENSE).
