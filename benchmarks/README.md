# rasterizer timing comparison

i made two small quartus projects so the touchscreen and display dont affect
the rasterizer timing results:

- `baseline/baseline_benchmark.qpf` measures the archived one-pixel rasterizer
  in `original_version/`.
- `optimized/optimized_benchmark.qpf` measures the active eight-pixel,
  two-stage pipelined rasterizer in `rtl/`.

both use the same EP4CE6E22C8 chip and the same quartus settings. i gave them
a 1 ns clock on purpose so timequest would show the actual restricted fmax.

open either `.qpf`, go to Processing > Start Compilation, then look for the
fmax summary in the compilation report. the clock is called `raster_clk`.
throughput is the old fmax times 1 pixel or the new fmax times 8 pixels.

## results from quartus 25.1 standard

i already compiled both with the slow 1200 mV 85 C timing model.

| Design | Restricted Fmax | Pixels/clock | Estimated throughput | Logic cells | RAM segments | DSP elements |
|---|---:|---:|---:|---:|---:|---:|
| Baseline | 59.01 MHz | 1 | 59.01 Mpixels/s | 608 | 10 | 12 |
| Parallel + pipelined | 87.15 MHz | 8 | 697.20 Mpixels/s | 1,471 | 16 | 12 |

the new one gets about 11.8x the estimated pixel throughput and its fmax is
47.7% higher, but it uses more logic and ram. the missing pin warnings and the
failed 1 GHz timing target are normal here. these projects are only for timing
tests and arent meant to be loaded onto the board.
