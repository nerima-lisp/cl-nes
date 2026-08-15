# Development

The repository keeps the emulator source, tests, command-line wrappers, and
documentation in separate areas.

## Source and tests

- src/ contains the package, cartridge, device, bus, CPU, APU, PPU, and NES
  layers. CPU state, shared addressing helpers, ALU operations, control flow,
  opcode dispatch, APU channel units, frame sequencing, and cycle orchestration
  are kept in separate source components. Register-heavy subsystems keep their
  immutable decode tables in dedicated `*-data.lisp` files and generate the
  repetitive write paths with macros so hardware constants stay auditable while
  the runtime path remains direct. That split now covers CPU ALU unofficial
  helper bodies as data-driven generated definitions as well, so opcode-side
  irregularities stay grouped in one review surface instead of being spread
  across the runtime file. CPU opcode-range dispatch follows the same rule:
  the declarative `#x00-#x7F` and `#x80-#xFF` tables live in dedicated
  `src/cpu-opcodes-*-data.lisp` files, while the runtime files keep the BRK,
  stack, jump, and unstable-store handlers that are not plain table entries.
  MMC5 expansion-register decode follows the same rule: the fixed register map
  lives in `src/cartridge-mapper5-control-data.lisp`, while
  `src/cartridge-mapper5-control.lisp` only keeps the range writes and
  read/write side effects that are not plain field assignments.
- t/ contains the complete cl-weave test system. State-transition contracts
  are grouped by subsystem in `cpu-state-transitions.lisp`,
  `cpu-addressing-transitions.lisp`, `cpu-interrupt-transitions.lisp`,
  `nes-transitions.lisp`, `ppu-register-transitions.lisp`, and
  `bus-transitions.lisp`; property and state-machine contracts live in
  `properties.lisp`. Reusable fixture builders, cartridge constructors,
  expectation helpers, and macro support stay in dedicated support files so
  subsystem contracts can stay focused on the behavior under test. Runtime
  coverage files are split by subsystem as well, so PPU timing/rendering
  probes and NES lifecycle/interrupt probes do not accumulate in one file.
- run-tests.lisp is the thin launcher for the canonical ASDF test system; it
  does not load test files independently.
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

The 2026 refactoring policy is deliberately selective. `defmacro` is used for
compile-time dispatch and repetitive register/opcode write paths where the
input tables are the source of truth; stateful hardware behavior stays in
ordinary functions so evaluation order, mutation, and stack use remain visible.
The public CPS entry points (`nes-step/k` and `nes-run-frame/k`) expose
continuation boundaries, while frame stepping keeps an iterative loop so long
frames do not grow the call stack. Data tables and generated definitions are
kept apart from runtime logic, and no compatibility aliases or adapter layer
are retained for removed APIs.

The organization repository was reviewed for additional dependencies. The
current pins are the latest release tags: cl-weave v1.3.0 and paredit-cli
v1.6.0. `cl-process-kit` was not added: it is an SBCL-only process toolkit for
launchers and test infrastructure, not a dependency of the deterministic,
dependency-free emulator core. This keeps package selection purposeful rather
than coupling runtime behavior to unrelated infrastructure.

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

The coverage runner fails when instrumentation is empty and enforces 100% for
both expression and branch coverage. Constructor and loader keyword defaults
have explicit coverage contracts. The aggregate excludes only the
ASDF-required `in-package` form in each measured file and the load-time PPU
decay constant; all runtime forms remain instrumented. Condition type
declarations are excluded because they declare the condition hierarchy but do
not contain runtime paths; compile-time macros and pure state layouts are
likewise kept outside the runtime measurement set. The flake check evaluates
the declared formatter, bounds each emulator and documentation command with a
finite timeout, compiles the ASDF system, runs the canonical test and coverage
checks, and builds the documentation strictly into a temporary site directory.

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
status=0
found=0
for rom in roms/*.nes; do
  [ -f "$rom" ] || continue
  found=1
  sbcl --script run-rom-suite.lisp "$rom" 1000000 mmc3 || status=1
done
[ "$found" -eq 1 ] || { printf '%s\n' 'no ROMs found' >&2; exit 2; }
exit "$status"
~~~

Select `mmc3`, `mmc6`, or `mmc3-alt` for mapper 4 ROMs as appropriate. The
reported status is the result of the bounded invocation (`pass`, `fail`,
`limit`, `no-result`, `unsupported`, `invalid`, or `error`); a corpus result
does not imply compatibility with every NES ROM.
