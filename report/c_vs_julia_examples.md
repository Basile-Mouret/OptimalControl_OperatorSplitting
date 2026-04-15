# C vs Julia Example Comparison

Cold-start comparison on the exact `osc/<example>/data/<size>/` fixtures.

Notes:
- C numbers come from `run_osc` and are the reported average over 100 cold starts.
- Julia numbers are warmed first, then averaged over 100 cold starts on the same fixture data, with the cache state reset between solves.
- Both sides are run in single-thread mode (`OMP_NUM_THREADS=1`, `JULIA_NUM_THREADS=1`, `BLAS.set_num_threads(1)`).
- `C factor ms` is the factorization time reported by the C code.
- `Julia setup ms` is one warmed `setup_cache(data)` call and therefore includes Julia-side KKT assembly plus factorization.

| Example | Size | C factor ms | Julia setup ms | C iters | Julia iters | Δ iters | C total ms | Julia total ms | Δ total ms | Julia/C total | C lin ms/iter | Julia lin ms/iter | C prox ms/iter | Julia prox ms/iter | Julia converged |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| `box` | `small` | 0.040 | 0.111 | 92.000 | 92.000 | 0.000 | 0.190 | 0.948 | 0.758 | 4.989 | 0.000 | 0.010 | 0.000 | 0.000 | true |
| `box` | `medium` | 0.960 | 1.289 | 46.000 | 46.000 | 0.000 | 1.870 | 1.698 | -0.172 | 0.908 | 0.040 | 0.035 | 0.000 | 0.000 | true |
| `box` | `large` | 9.310 | 23.055 | 68.000 | 68.000 | 0.000 | 24.220 | 18.838 | -5.382 | 0.778 | 0.350 | 0.269 | 0.001 | 0.000 | true |
| `finance` | `small` | 0.380 | 0.633 | 27.000 | 27.000 | -0.000 | 0.610 | 0.706 | 0.096 | 1.158 | 0.020 | 0.023 | 0.001 | 0.001 | true |
| `finance` | `medium` | 7.310 | 93.848 | 41.000 | 41.000 | -0.000 | 12.600 | 12.971 | 0.371 | 1.029 | 0.280 | 0.297 | 0.007 | 0.005 | true |
| `finance` | `large` | 39.450 | 99.172 | 53.000 | 53.000 | 0.000 | 72.690 | 100.321 | 27.631 | 1.380 | 1.290 | 1.828 | 0.028 | 0.014 | true |
| `rob_est` | `small` | 0.220 | 0.460 | 21.000 | 21.000 | 0.000 | 0.370 | 0.512 | 0.142 | 1.383 | 0.010 | 0.021 | 0.001 | 0.001 | true |
| `rob_est` | `medium` | 4.750 | 30.627 | 25.000 | 25.000 | 0.000 | 6.670 | 7.182 | 0.512 | 1.077 | 0.250 | 0.266 | 0.004 | 0.006 | true |
| `rob_est` | `large` | 26.340 | 67.332 | 29.000 | 29.000 | -0.000 | 32.830 | 40.169 | 7.339 | 1.224 | 1.060 | 1.331 | 0.014 | 0.007 | true |
| `sup_ch` | `small` | 0.130 | 0.321 | 82.000 | 82.000 | -0.000 | 6.720 | 3.739 | -2.981 | 0.556 | 0.000 | 0.008 | 0.075 | 0.035 | true |
| `sup_ch` | `medium` | 0.810 | 87.042 | 77.000 | 77.000 | 0.000 | 30.040 | 11.594 | -18.446 | 0.386 | 0.030 | 0.039 | 0.350 | 0.102 | true |
| `sup_ch` | `large` | 3.220 | 28.200 | 116.000 | 116.000 | -0.000 | 154.360 | 43.711 | -110.649 | 0.283 | 0.110 | 0.127 | 1.168 | 0.219 | true |
