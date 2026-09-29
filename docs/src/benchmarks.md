# Benchmarks

The measurements below use SBCL 2.6.6 on aarch64-darwin. Each benchmark uses
two warmup batches, ten samples, and 60 frames per sample. Full GC runs before
each measured sample. Wall-clock values are diagnostic only because the host
was shared; allocation counts are the useful comparison for this change.

## CPU operation allocation

The previous rendering-enabled probe measured 2,085,059 bytes per frame. After
replacing the per-operation bus hook closure and the per-step local callbacks
with bus state slots and named callbacks, the integrated benchmark measured
23,561.600 bytes per frame (median, 23,543.467 minimum, 24,633.600 maximum).

The remaining frame allocation is in the existing PPU renderer's per-frame
scratch arrays. The PPU renderer is owned by a separate stream and is not
changed by this phase.

The allocation gate follows `nerima-lisp/.github/PERFORMANCE_STANDARD.md`:
it compares the minimum bytes consed by the rendering-enabled loop with the
same CPU/frame loop with rendering disabled, after a full GC and ten samples.
Until the PPU stream removes the legacy renderer, the gate explicitly permits
the known two `256x240` bit-array payloads (15,360 bytes/frame) plus a bounded
runtime overhead allowance. This is a known exception, not an absolute
allocation threshold.

## Rendering-enabled workload

| Workload | Median ms/frame | Min | Max | Median bytes/frame |
| --- | ---: | ---: | ---: | ---: |
| NROM, `PPUMASK=$18` | 11.862 | 10.583 | 12.426 | 23,561.600 |
| MMC3 bank switching and scanline IRQ | 13.879 | 12.612 | 15.122 | 24,244.267 |

The integrated benchmark was run with load averages `54.77 67.11 81.87`.
The earlier baseline probe was run with load averages between 83 and 100, so
its wall-clock values are not directly comparable.

Reproduce with:

```sh
nix develop -c timeout 600 sbcl --noinform --non-interactive \
  --load benchmark/run-benchmarks.lisp --quit
```
