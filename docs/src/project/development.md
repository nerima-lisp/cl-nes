# Development

The repository keeps the emulator source, tests, command-line wrappers, and
documentation in separate areas.

## Source and tests

- src/ contains the package, cartridge, device, bus, CPU, and NES layers.
- t/ contains the complete regression test system, including the legacy
  assertion corpus and its `cl-nes/test-runner` entry point.
- run-tests.lisp is a thin standalone launcher for that ASDF-loaded legacy
  runner; it does not load test files independently.
- run-weave-tests.lisp runs the cl-weave suite, including generated property
  contracts and the legacy corpus.
- run-coverage.lisp writes the SBCL expression and branch report under
  coverage/.

The ASDF test system is cl-nes/test. The main ASDF system is cl-nes.

## Dependency policy

The emulator runtime remains dependency-free: its deterministic device model
does not need transport, retry, logging, or boundary adapters. cl-weave is
test-only and provides the regression, property, and state-machine contracts;
paredit-cli is a development tool for structure-aware Lisp editing. Keeping
those concerns outside the runtime preserves direct data and logic paths.

The flake publishes checks and development shells for aarch64-darwin,
aarch64-linux, and x86_64-linux. x86_64-darwin is not declared because the
pinned nixpkgs release no longer supports that platform.
The pinned paredit-cli package is included on systems where its v1.6.0 flake
publishes a package; its current upstream output omits aarch64-linux.

## Verification

Enter the pinned environment and run the focused checks:

~~~sh
nix develop
sbcl --noinform --non-interactive --load run-tests.lisp --quit
sbcl --noinform --non-interactive --load run-weave-tests.lisp --quit
nix flake check
~~~

Run coverage separately when its generated report is needed:

~~~sh
sbcl --noinform --non-interactive --load run-coverage.lisp --quit
~~~

The coverage runner fails when instrumentation is empty and enforces a
non-regression floor for expression and branch coverage. The long-term target
is 100% for both categories. Constructor and loader keyword defaults have
explicit coverage contracts. On SBCL, the current residual report consists of
the source-level `in-package` declaration in each measured file and the
constant init-forms in keyword lambda lists; SB-COVER does not expose
form-level exclusions for these declarations. Condition type declarations are
excluded because they declare the condition hierarchy but do not contain
runtime paths. The flake check evaluates the declared formatter, bounds each
emulator and documentation command with a finite timeout, runs the regression,
weave, and coverage checks, and builds the documentation strictly into a
temporary site directory.

## Documentation

The manual source is under docs/src and the MkDocs configuration is
docs/mkdocs.yml. The pinned development shell includes MkDocs Material; build
it strictly from the repository root:

~~~sh
mkdocs build --strict -f docs/mkdocs.yml
~~~

The navigation is declared in the configuration so missing pages and broken
navigation entries are visible during a strict build.

## ROM tools

run-nes.lisp loads one iNES ROM and writes binary PPM frames:

~~~sh
sbcl --script run-nes.lisp ROM.nes [frames] [output-prefix]
~~~

run-rom-suite.lisp executes a ROM for a bounded number of steps and prints TSV
diagnostics. Its optional third argument selects the mapper 4 variant:

~~~sh
sbcl --script run-rom-suite.lisp ROM.nes [max-steps] [mmc3|mmc6]
~~~
