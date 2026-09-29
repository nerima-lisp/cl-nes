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

The benchmark goal is to keep the rendering-enabled allocation at or below the
current integrated reference while preserving both synthetic workloads. The
allocation gate follows `nerima-lisp/.github/PERFORMANCE_STANDARD.md`: it
compares the minimum bytes consed by the rendering-enabled loop with the same
CPU/frame loop with rendering disabled, after a full GC and ten samples.
Until the PPU stream removes the legacy renderer, the gate explicitly permits
the known two `256x240` bit-array payloads (15,360 bytes/frame) plus a bounded
runtime overhead allowance. This is a known exception, not an absolute
allocation threshold.

## Rendering-enabled workload

| Workload | Median ms/frame | Min | Max | Median bytes/frame |
| --- | ---: | ---: | ---: | ---: |
| NROM, `PPUMASK=$18` | 9.268 | 8.633 | 10.491 | 24,777.600 |
| MMC3 bank switching and scanline IRQ | 10.530 | 9.898 | 11.220 | 24,453.333 |

The integrated benchmark was run with load averages `38.40 41.99 59.56`.
The earlier baseline probe was run with load averages between 83 and 100, so
its wall-clock values are not directly comparable.

The benchmark is diagnostic rather than a pull-request gate. Reproduce with:

```sh
nix run .#bench
```

The success criteria are a zero exit status, two warmup batches, ten measured
samples of 60 frames each, and both the NROM and MMC3 workloads completing with
median/minimum/maximum time and allocation results. Wall-clock measurements
are for comparison only; the allocation trend is the primary benchmark goal.
