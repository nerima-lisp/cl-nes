# Development

The repository keeps the emulator source, tests, command-line wrappers, and
documentation in separate areas.

## Source and tests

- src/ contains the package, cartridge, device, bus, CPU, APU, PPU, and NES
  layers. CPU state, shared addressing helpers, ALU operations, control flow,
  opcode dispatch, APU channel units, frame sequencing, and cycle orchestration
  are kept in separate source components. The APU components are loaded in
  `cl-nes.asd` order: `apu-data.lisp`, `apu-state.lisp`,
  `apu-construction.lisp`, `apu.lisp`, `apu-lifecycle.lisp`,
  `apu-envelopes.lisp`, `apu-timers.lisp`, `apu-frame.lisp`,
  `apu-timing.lisp`, `apu-status.lisp`, `apu-registers.lisp`, and
  `apu-output.lisp`.
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

## Worktree lifecycle

Treat each branch or worktree as one reviewable unit. Before integrating it,
compare its tip with `main` using `git merge-base --is-ancestor` and inspect
both tracked and untracked changes. A clean worktree whose tip is already
reachable from `main` is redundant and can be removed after the reference
check; a dirty worktree stays in place until its changes have been assigned to
an owner and split into explicit commits.

In the bare-repository layout, inspect branches with `git -C <repository>
...` and inspect a worktree with `git -C <worktree> ...`; running `git status`
from the `.worktrees` container itself does not address a worktree. Integrate
each completed unit into `main`, re-check reachability, and only then remove
that unit's worktree.

After a unit is integrated, verify that its commit is reachable from `main`
before deleting the completed worktree or branch. Scratch probes and generated
artifacts should be removed once their result has been recorded, while
unfinished source changes must remain available for their next integration
step. Keep the canonical test and documentation commands below tied to the
integrated `main` tree so cleanup does not hide an unverified change.

## Dependency policy

The emulator runtime carries one runtime dependency: [cl-host-kit](https://github.com/nerima-lisp/cl-host-kit)
supplies `read-file-octets` for cartridge ROM file reads (L1, depth 0).
[cl-weave](https://github.com/nerima-lisp/cl-weave) is test-only and provides
the regression, property, and state-machine contracts;
[paredit-cli](https://github.com/nerima-lisp/paredit-cli) is a dev-time
structural refactoring tool, never linked into the Lisp image. Keeping those
concerns outside the runtime preserves direct data and logic paths, so
unrelated organization packages are not pulled into the core merely for
infrastructure.

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
current pins are the latest release tags: cl-host-kit v0.3.1, cl-weave
v1.3.0, and paredit-cli v1.6.3. cl-nix-forge is pinned to v0.6.1.
`cl-process-kit` was not added: it is an
SBCL-only process toolkit for launchers and test infrastructure, unrelated to
cartridge ROM reads, the one runtime need this core has. This keeps package
selection purposeful rather than coupling runtime behavior to unrelated
infrastructure.

The flake, migrated to the [cl-nix-forge](https://github.com/nerima-lisp/cl-nix-forge)
`mkPackageFlake` preset, publishes checks, development shells, and a
benchmark app for x86_64-linux and aarch64-darwin: x86_64-linux is what CI
would gate, aarch64-darwin is the development machine this repository is
actually built on today. aarch64-linux and x86_64-darwin are left out;
neither was covered by this repository's own tooling in a way it could
verify.

## Verification

Enter the pinned environment and run the focused checks:

~~~sh
nix develop
sbcl --noinform --non-interactive --eval '(require :asdf)' --load cl-nes.asd --eval '(asdf:compile-system "cl-nes" :force t)' --quit
sbcl --noinform --non-interactive --load run-tests.lisp --quit
nix flake check
~~~

Before integrating a branch into `main`, run the ROM contract suite with both
test-ROM and AccuracyCoin paths configured. Unit tests alone do not exercise
the cycle-level ROM contracts or the AccuracyCoin item ratchet.

~~~sh
CL_NES_TEST_ROMS=/path/to/nes-test-roms \
CL_NES_ACCURACY_COIN=/path/to/AccuracyCoin.nes \
sbcl --noinform --non-interactive --load run-rom-suite.lisp --quit
~~~

The suite must finish with no unexpected contract failure, and AccuracyCoin
must not lose any previously passing item. Update the declared contract only
when an item is intentionally promoted or its failure is explained by a
verified implementation change.

Run coverage separately when its generated report is needed:

~~~sh
sbcl --noinform --non-interactive --load run-coverage.lisp --quit
~~~

Performance measurements are documented separately when a reproducible,
repository-supported benchmark command is available. `ci.yml` is the single
required GitHub Actions job and runs `nix flake check` on `ubuntu-latest`.

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

## Frontend and ROM diagnostics

The `cl-nes` executable provides the frontend commands. Its version is
available without a ROM:

~~~sh
cl-nes --version
~~~

Use `play` for the interactive GLFW/OpenGL frontend, `render` for numbered
PPM/PNG output, and `rom-test` for a bounded diagnostic protocol:

~~~sh
cl-nes play ROM.nes [--state-directory PATH] [--scale INTEGER]
cl-nes render ROM.nes [--frames INTEGER] [--prefix PREFIX] [--format ppm|png]
cl-nes rom-test ROM.nes [--max-frames INTEGER]
~~~

The frontend does not download or bundle ROM files. Use a self-created,
homebrew, public-domain, or otherwise legally obtained corpus. A bounded ROM
diagnostic is a startup/protocol smoke check, not evidence of complete
instruction, timing, audio, mapper, or game-level compatibility. Keep
generated frames, save files, and test corpora outside the checkout unless
their redistribution rights are explicit.

Record the source URL or repository, revision, per-file SHA-256, and applicable
license or permission next to any corpus used for repeatable validation. A
repository's presence in a test-ROM collection is not, by itself, permission
to redistribute its files. Do not commit ROM binaries or a manifest containing
machine-specific absolute paths. A one-frame result is a startup smoke check;
it does not establish instruction, timing, audio, mapper, or game-level
compatibility. Use the focused emulator tests and ROM-specific diagnostic
protocols for those claims.

Development-only synthetic ROMs can exercise supported mapper IDs and mapper 4
variants without storing ROM files in the repository. Keep those generated
artifacts outside the checkout and use the same bounded diagnostic command as
for a legally obtained corpus. Mapper 5 cases that access PRG-RAM must first
unlock it with the mapper's protection registers; a locked read is a valid
hardware state, not evidence that the ROM loader failed.

The validation corpus for this refactor was kept outside the checkout and
covered every mapper named in the compatibility reference, including
mirroring, trainer, and PRG-RAM variants. Preserve the per-ROM diagnostic output
when recording a comparable validation run.
