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
| `box` | `small` | 0.050 | 0.136 | 92.000 | 92.000 | 0.000 | 0.160 | 0.368 | 0.208 | 2.302 | 0.000 | 0.003 | 0.000 | 0.000 | true |
| `box` | `medium` | 0.640 | 1.012 | 46.000 | 46.000 | 0.000 | 1.200 | 1.426 | 0.226 | 1.188 | 0.020 | 0.029 | 0.000 | 0.000 | true |
| `box` | `large` | 8.420 | 25.576 | 68.000 | 68.000 | 0.000 | 17.940 | 19.960 | 2.020 | 1.113 | 0.260 | 0.282 | 0.001 | 0.001 | true |
| `finance` | `small` | 0.360 | 0.659 | 27.000 | 27.000 | -0.000 | 0.450 | 1.446 | 0.996 | 3.212 | 0.010 | 0.050 | 0.001 | 0.001 | true |
| `finance` | `medium` | 7.280 | 106.229 | 41.000 | 41.000 | -0.000 | 10.310 | 13.485 | 3.175 | 1.308 | 0.230 | 0.305 | 0.007 | 0.005 | true |
| `finance` | `large` | 40.430 | 168.067 | 53.000 | 53.000 | 0.000 | 72.400 | 112.151 | 39.751 | 1.549 | 1.290 | 2.030 | 0.025 | 0.016 | true |
| `rob_est` | `small` | 0.250 | 0.496 | 21.000 | 21.000 | 0.000 | 0.300 | 0.520 | 0.220 | 1.732 | 0.010 | 0.022 | 0.001 | 0.001 | true |
| `rob_est` | `medium` | 4.600 | 39.069 | 25.000 | 25.000 | 0.000 | 4.950 | 6.728 | 1.778 | 1.359 | 0.180 | 0.247 | 0.003 | 0.004 | true |
| `rob_est` | `large` | 25.840 | 144.380 | 29.000 | 29.000 | -0.000 | 29.080 | 42.526 | 13.446 | 1.462 | 0.940 | 1.401 | 0.011 | 0.006 | true |
| `sup_ch` | `small` | 0.190 | 0.384 | 82.000 | 82.000 | -0.000 | 6.120 | 3.025 | -3.095 | 0.494 | 0.000 | 0.007 | 0.069 | 0.028 | true |
| `sup_ch` | `medium` | 0.800 | 87.418 | 77.000 | 77.000 | 0.000 | 26.910 | 11.177 | -15.733 | 0.415 | 0.030 | 0.034 | 0.316 | 0.102 | true |
| `sup_ch` | `large` | 2.620 | 33.055 | 116.000 | 116.000 | -0.000 | 122.430 | 47.856 | -74.574 | 0.391 | 0.090 | 0.143 | 0.936 | 0.227 | true |
