# Development

The repository keeps the emulator source, tests, command-line wrappers, and
documentation in separate areas.

## Source and tests

- src/ contains the package, cartridge, device, bus, CPU, APU, PPU, and NES
  layers. CPU state, shared addressing helpers, ALU operations, control flow,
  opcode dispatch, APU channel units, frame sequencing, and cycle orchestration
  are kept in separate source components.
- t/ contains the complete cl-weave test system. State-transition contracts
  are grouped by subsystem in `cpu-transition-fixtures.lisp`,
  `cpu-state-transitions.lisp`, `cpu-hardware-interrupt-transitions.lisp`,
  `cpu-flag-transitions.lisp`, `cpu-addressing-transitions.lisp`,
  `nes-transitions.lisp`, `ppu-transition-fixtures.lisp`,
  `ppu-register-memory-transitions.lisp`,
  `ppu-nametable-memory-transitions.lisp`,
  `ppu-mmc5-memory-transitions.lisp`,
  `ppu-background-rendering-transitions.lisp`,
  `ppu-sprite-rendering-transitions.lisp`, `ppu-timing-transitions.lisp`,
  `bus-routing-transitions.lisp`, and `bus-memory-transitions.lisp`.
- run-tests.lisp loads the ASDF test system and forwards focused cl-weave
  selection from environment variables without requiring ad hoc edits to the
  test files.
- run-coverage.lisp writes the SBCL expression and branch report under
  coverage/.

The ASDF test system is cl-nes/test. The main ASDF system is cl-nes.

## Dependency policy

The emulator runtime remains dependency-free: its deterministic device model
does not need transport, retry, logging, or boundary adapters. [cl-weave](https://github.com/nerima-lisp/cl-weave)
is test-only and provides the regression, property, and state-machine
contracts; [paredit-cli](https://github.com/nerima-lisp/paredit-cli) is a
development tool for structure-aware Lisp editing. Keeping those concerns
outside the runtime preserves direct data and logic paths, so unrelated
organization packages are not pulled into the core merely for infrastructure.

The flake publishes checks and development shells for aarch64-darwin,
aarch64-linux, and x86_64-linux. x86_64-darwin is not declared because the
pinned nixpkgs release no longer supports that platform.
The pinned paredit-cli package is included on systems where its v1.6.0 flake
publishes a package; its current upstream output omits aarch64-linux.

## Verification

Enter the pinned environment and run the focused checks:

~~~sh
nix develop
sbcl --noinform --non-interactive --eval '(require :asdf)' --load cl-nes.asd --eval '(asdf:compile-system "cl-nes" :force t)' --quit
sbcl --noinform --non-interactive --load run-tests.lisp --quit
nix flake check
~~~

Run coverage separately when its generated report is needed:

~~~sh
sbcl --noinform --non-interactive --load run-coverage.lisp --quit
~~~

Focused cl-weave runs use the same launcher and optional environment
variables:

~~~sh
CL_NES_TEST_NAME_FILTER=mmc1 \
CL_NES_TEST_LOCATION_FILTER=t/coverage-mapper-contracts.lisp \
CL_NES_TEST_PATH_FILTER='mapper contracts > mmc1 updates mirroring and chr banks' \
CL_NES_TEST_INCLUDE_TAGS=mapper,contracts \
CL_NES_TEST_EXCLUDE_TAGS=slow \
CL_NES_TEST_REPORTER=spec \
CL_NES_TEST_SEED=20260813 \
CL_NES_TEST_TIMEOUT_MS=1000 \
CL_NES_TEST_MAX_WORKERS=1 \
sbcl --noinform --non-interactive --load run-tests.lisp --quit
~~~

`CL_NES_TEST_LOCATION_FILTER` and `CL_NES_TEST_PATH_FILTER` accept
comma-separated lists. Test paths use cl-weave's `suite > nested suite > test`
spelling. Direct `asdf:test-system "cl-nes/test"` execution still runs the
entire suite with the system's built-in `:spec` reporter.

The coverage runner fails when instrumentation or generated report files are
empty and enforces a non-regression floor for expression and branch coverage.
The long-term target is 100% for both categories. Constructor and loader
keyword defaults have explicit coverage contracts. The deterministic
`coverage-summary.txt` contains aggregate totals followed by one row per
measured source file, making the remaining test seams reviewable without
depending on temporary HTML paths. Condition type declarations are excluded
because they declare the condition hierarchy but do not contain runtime paths;
package declarations, compile-time macros, and pure state layouts are likewise
kept outside the runtime measurement set. The flake check
evaluates the declared formatter, bounds each emulator and documentation
command with a finite timeout, compiles the ASDF
system, runs the canonical test and coverage checks, and builds the
documentation strictly into a temporary site directory.

The reproducible native-system gate can also be invoked directly:

~~~sh
nix build .#checks.aarch64-darwin.cl-nes --print-build-logs
~~~

That derivation checks every Lisp source file with `paredit-cli`, rejects an
empty cl-weave test suite, generates the SBCL coverage artifacts, and builds
this manual with strict MkDocs navigation. The working build keeps the HTML
reports and `sb-cover.data` for local inspection. The published Nix check output
contains only the deterministic `coverage-summary.txt`; the raw reports embed
temporary build paths and would make a content-addressed output
non-reproducible. Long-running phases use the pinned Coreutils `timeout`
executable from the Nix environment.

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
sbcl --script run-rom-suite.lisp ROM.nes [max-steps] [mmc3|mmc6|mmc3-alt]
~~~

The wrapper accepts one ROM per invocation. It does not download or bundle ROM
files; use a self-created, homebrew, public-domain, or otherwise legally
obtained corpus. A bounded batch run can preserve one TSV row per ROM while
still failing overall when any ROM does not pass:

~~~sh
result=0
found=0
for rom in roms/*.nes; do
  [ -f "$rom" ] || continue
  found=1
  sbcl --script run-rom-suite.lisp "$rom" 1000000 mmc3 || result=1
done
[ "$found" -eq 1 ] || { printf '%s\n' 'no ROMs found' >&2; exit 2; }
exit "$result"
~~~

Select `mmc3`, `mmc6`, or `mmc3-alt` for mapper 4 ROMs as appropriate. The
reported status is the result of the bounded invocation (`pass`, `fail`,
`limit`, `no-result`, `unsupported`, `invalid`, or `error`); a corpus result
does not imply compatibility with every NES ROM.

Development-only synthetic ROMs can exercise supported mapper IDs and mapper 4
variants without storing ROM files in the repository. Keep those generated
artifacts outside the checkout and use the same bounded runner and TSV output
as for a legally obtained corpus. Mapper 5 cases that access PRG-RAM must first
unlock it with the mapper's protection registers; a locked read is a valid
hardware state, not evidence that the ROM loader failed.

The validation corpus for this refactor was kept outside the checkout and
covered every mapper named in the compatibility reference, including
mirroring, trainer, and PRG-RAM variants. Preserve the per-ROM TSV output when
recording a comparable validation run.
