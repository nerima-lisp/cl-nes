# Benchmarks

The measurements below use SBCL 2.6.6 on aarch64-darwin. Each benchmark uses
two warmup batches, ten samples, and 60 frames per sample. Full GC runs before
each measured sample. Wall-clock values are diagnostic only because the host
was shared; allocation counts are the useful comparison for this change.

## CPU operation allocation

The previous rendering-enabled probe measured 2,085,059 bytes per frame. After
replacing the per-operation bus hook closure and the per-step local callbacks
with bus state slots and named callbacks, the integrated benchmark measured
24,777.600 bytes per frame (median, 23,963.733 minimum, 24,985.600 maximum).

The PPU renderer now renders through the dot pipeline. Its background and
sprite visibility state lives in the existing pipeline registers and does not
allocate the legacy per-frame scratch arrays.

The allocation gate follows `nerima-lisp/.github/PERFORMANCE_STANDARD.md`:
it compares the minimum bytes consed by the rendering-enabled loop with the
same CPU/frame loop with rendering disabled, after a full GC and ten samples.
The gate has no PPU scratch allowance. Any remaining allocation must therefore
be accounted for by the shared baseline rather than an exception for the old
renderer.

## Rendering-enabled workload

| Workload | Median ms/frame | Min | Max | Median bytes/frame |
| --- | ---: | ---: | ---: | ---: |
| NROM, `PPUMASK=$18` | 9.268 | 8.633 | 10.491 | 24,777.600 |
| MMC3 bank switching and scanline IRQ | 10.530 | 9.898 | 11.220 | 24,453.333 |

The integrated benchmark was run with load averages `38.40 41.99 59.56`.
The earlier baseline probe was run with load averages between 83 and 100, so
its wall-clock values are not directly comparable.

Reproduce with:

```sh
nix develop -c timeout 600 sbcl --noinform --non-interactive \
  --load benchmark/run-benchmarks.lisp --quit
```
