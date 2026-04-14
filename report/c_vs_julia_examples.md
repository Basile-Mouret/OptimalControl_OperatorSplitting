# C vs Julia Example Comparison

Cold-start comparison on the exact `osc/<example>/data/<size>/` fixtures.

Notes:
- C numbers come from `run_osc` and are the reported average over 100 cold starts.
- Julia numbers are warmed first, then averaged over 100 cold starts on the same fixture data, with the cache state reset between solves.
- `C factor ms` is the factorization time reported by the C code.
- `Julia setup ms` is one warmed `setup_cache(data)` call and therefore includes Julia-side KKT assembly plus factorization.

| Example | Size | C factor ms | Julia setup ms | C iters | Julia iters | Δ iters | C total ms | Julia total ms | Δ total ms | Julia/C total | C lin ms/iter | Julia lin ms/iter | C prox ms/iter | Julia prox ms/iter | Julia converged |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| `box` | `small` | 0.050 | 0.222 | 92.000 | 92.000 | 0.000 | 0.180 | 0.550 | 0.370 | 3.055 | 0.000 | 0.005 | 0.000 | 0.000 | true |
| `box` | `medium` | 0.690 | 1.278 | 46.000 | 46.000 | 0.000 | 1.410 | 2.388 | 0.978 | 1.694 | 0.030 | 0.048 | 0.000 | 0.000 | true |
| `box` | `large` | 9.070 | 98.871 | 68.000 | 68.000 | 0.000 | 18.440 | 16.678 | -1.762 | 0.904 | 0.260 | 0.232 | 0.001 | 0.001 | true |
| `finance` | `small` | 0.300 | 0.627 | 27.000 | 27.000 | -0.000 | 0.410 | 1.623 | 1.213 | 3.957 | 0.010 | 0.055 | 0.001 | 0.001 | true |
| `finance` | `medium` | 6.700 | 20.665 | 41.000 | 41.000 | -0.000 | 9.490 | 11.447 | 1.957 | 1.206 | 0.210 | 0.253 | 0.006 | 0.005 | true |
| `finance` | `large` | 40.590 | 138.049 | 53.000 | 53.000 | 0.000 | 78.390 | 101.497 | 23.107 | 1.295 | 1.410 | 1.826 | 0.025 | 0.014 | true |
| `rob_est` | `small` | 0.340 | 0.540 | 21.000 | 21.000 | 0.000 | 0.300 | 1.492 | 1.192 | 4.973 | 0.010 | 0.066 | 0.001 | 0.001 | true |
| `rob_est` | `medium` | 4.290 | 20.713 | 25.000 | 25.000 | 0.000 | 4.720 | 5.762 | 1.042 | 1.221 | 0.170 | 0.204 | 0.003 | 0.004 | true |
| `rob_est` | `large` | 26.360 | 75.126 | 29.000 | 29.000 | -0.000 | 27.940 | 41.459 | 13.519 | 1.484 | 0.910 | 1.351 | 0.012 | 0.006 | true |
| `sup_ch` | `small` | 0.190 | 0.462 | 82.000 | 82.000 | -0.000 | 5.060 | 3.454 | -1.606 | 0.683 | 0.010 | 0.007 | 0.048 | 0.030 | true |
| `sup_ch` | `medium` | 1.130 | 1.629 | 77.000 | 77.000 | 0.000 | 24.940 | 12.033 | -12.907 | 0.482 | 0.060 | 0.034 | 0.243 | 0.107 | true |
| `sup_ch` | `large` | 2.700 | 20.906 | 116.000 | 116.000 | -0.000 | 110.410 | 45.314 | -65.096 | 0.410 | 0.180 | 0.129 | 0.704 | 0.211 | true |
