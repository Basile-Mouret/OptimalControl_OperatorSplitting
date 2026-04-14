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
| `box` | `small` | 0.050 | 0.136 | 92.000 | 92.000 | 0.000 | 0.200 | 1.030 | 0.830 | 5.152 | 0.000 | 0.011 | 0.000 | 0.000 | true |
| `box` | `medium` | 0.700 | 1.089 | 46.000 | 46.000 | 0.000 | 1.200 | 2.191 | 0.991 | 1.826 | 0.020 | 0.046 | 0.000 | 0.000 | true |
| `box` | `large` | 7.720 | 22.431 | 68.000 | 68.000 | 0.000 | 17.980 | 16.222 | -1.758 | 0.902 | 0.260 | 0.229 | 0.001 | 0.001 | true |
| `finance` | `small` | 0.370 | 0.615 | 27.000 | 27.000 | -0.000 | 0.380 | 1.390 | 1.010 | 3.659 | 0.010 | 0.049 | 0.001 | 0.001 | true |
| `finance` | `medium` | 9.460 | 90.540 | 41.000 | 41.000 | -0.000 | 8.830 | 10.032 | 1.202 | 1.136 | 0.200 | 0.226 | 0.006 | 0.004 | true |
| `finance` | `large` | 36.850 | 158.130 | 53.000 | 53.000 | 0.000 | 60.490 | 87.834 | 27.344 | 1.452 | 1.080 | 1.592 | 0.020 | 0.012 | true |
| `rob_est` | `small` | 0.190 | 0.432 | 21.000 | 21.000 | 0.000 | 0.260 | 1.100 | 0.840 | 4.231 | 0.010 | 0.050 | 0.001 | 0.001 | true |
| `rob_est` | `medium` | 4.090 | 30.961 | 25.000 | 25.000 | 0.000 | 4.570 | 5.737 | 1.167 | 1.255 | 0.170 | 0.210 | 0.003 | 0.004 | true |
| `rob_est` | `large` | 23.850 | 128.277 | 29.000 | 29.000 | -0.000 | 24.780 | 34.935 | 10.155 | 1.410 | 0.810 | 1.151 | 0.009 | 0.005 | true |
| `sup_ch` | `small` | 0.170 | 0.317 | 82.000 | 82.000 | -0.000 | 5.910 | 2.865 | -3.045 | 0.485 | 0.000 | 0.007 | 0.066 | 0.027 | true |
| `sup_ch` | `medium` | 1.010 | 2.211 | 77.000 | 77.000 | 0.000 | 24.370 | 10.972 | -13.398 | 0.450 | 0.020 | 0.033 | 0.286 | 0.100 | true |
| `sup_ch` | `large` | 2.640 | 29.078 | 116.000 | 116.000 | -0.000 | 116.880 | 40.984 | -75.896 | 0.351 | 0.080 | 0.116 | 0.894 | 0.203 | true |
