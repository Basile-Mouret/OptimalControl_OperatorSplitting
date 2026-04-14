# C vs Julia Example Comparison

Cold-start comparison on the exact `osc/<example>/data/<size>/` fixtures.

Notes:
- C numbers come from `run_osc` and are the reported average over 100 cold starts.
- Julia numbers are warmed first, then averaged over 100 cold starts on the same fixture data, with the cache state reset between solves.
- `C factor ms` is the factorization time reported by the C code.
- `Julia setup ms` is one warmed `setup_cache(data)` call and therefore includes Julia-side KKT assembly plus factorization.

| Example | Size | C factor ms | Julia setup ms | C iters | Julia iters | Δ iters | C total ms | Julia total ms | Δ total ms | Julia/C total | C lin ms/iter | Julia lin ms/iter | C prox ms/iter | Julia prox ms/iter | Julia converged |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| `box` | `small` | 0.050 | 0.127 | 92.000 | 92.000 | 0.000 | 0.160 | 1.267 | 1.107 | 7.918 | 0.000 | 0.013 | 0.000 | 0.000 | true |
| `box` | `medium` | 0.620 | 0.964 | 46.000 | 46.000 | 0.000 | 1.200 | 1.326 | 0.126 | 1.105 | 0.020 | 0.027 | 0.000 | 0.000 | true |
| `box` | `large` | 8.100 | 23.382 | 68.000 | 68.000 | 0.000 | 17.810 | 16.309 | -1.501 | 0.916 | 0.250 | 0.230 | 0.001 | 0.001 | true |
| `finance` | `small` | 0.390 | 0.684 | 27.000 | 27.000 | -0.000 | 0.510 | 0.699 | 0.189 | 1.370 | 0.020 | 0.023 | 0.001 | 0.001 | true |
| `finance` | `medium` | 6.940 | 11.716 | 41.000 | 41.000 | -0.000 | 9.750 | 12.384 | 2.634 | 1.270 | 0.220 | 0.279 | 0.007 | 0.005 | true |
| `finance` | `large` | 40.060 | 170.300 | 53.000 | 53.000 | 0.000 | 74.300 | 92.257 | 17.957 | 1.242 | 1.330 | 1.673 | 0.025 | 0.013 | true |
| `rob_est` | `small` | 0.210 | 0.479 | 21.000 | 21.000 | 0.000 | 0.270 | 1.145 | 0.875 | 4.240 | 0.010 | 0.052 | 0.001 | 0.001 | true |
| `rob_est` | `medium` | 5.210 | 30.029 | 25.000 | 25.000 | 0.000 | 4.540 | 6.191 | 1.651 | 1.364 | 0.170 | 0.227 | 0.003 | 0.004 | true |
| `rob_est` | `large` | 24.090 | 120.561 | 29.000 | 29.000 | -0.000 | 25.820 | 37.034 | 11.214 | 1.434 | 0.840 | 1.221 | 0.009 | 0.005 | true |
| `sup_ch` | `small` | 0.120 | 0.471 | 82.000 | 82.000 | -0.000 | 3.530 | 3.742 | 0.212 | 1.060 | 0.010 | 0.007 | 0.035 | 0.036 | true |
| `sup_ch` | `medium` | 0.780 | 1.672 | 77.000 | 77.000 | 0.000 | 20.880 | 11.146 | -9.734 | 0.534 | 0.060 | 0.034 | 0.189 | 0.101 | true |
| `sup_ch` | `large` | 4.060 | 20.128 | 116.000 | 116.000 | -0.000 | 119.740 | 42.619 | -77.121 | 0.356 | 0.170 | 0.120 | 0.790 | 0.211 | true |
