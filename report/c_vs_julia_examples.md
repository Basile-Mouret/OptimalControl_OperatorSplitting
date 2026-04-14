# C vs Julia Example Comparison

Cold-start comparison on the exact `osc/<example>/data/<size>/` fixtures.

Notes:
- C numbers come from `run_osc` and are the reported average over 100 cold starts.
- Julia numbers are the average over 100 cold starts on the same fixture data, with the cache state reset between solves.
- `C factor ms` is the factorization time reported by the C code.
- `Julia setup ms` is one `setup_cache(data)` call and therefore includes Julia-side KKT assembly plus factorization.

| Example | Size | C factor ms | Julia setup ms | C iters | Julia iters | Δ iters | C total ms | Julia total ms | Δ total ms | Julia/C total | C lin ms/iter | Julia lin ms/iter | C prox ms/iter | Julia prox ms/iter | Julia converged |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| `box` | `small` | 0.040 | 87.823 | 92.000 | 92.000 | 0.000 | 0.140 | 0.500 | 0.360 | 3.571 | 0.000 | 0.004 | 0.000 | 0.000 | true |
| `box` | `medium` | 0.570 | 89.532 | 46.000 | 46.000 | 0.000 | 1.190 | 2.195 | 1.005 | 1.845 | 0.020 | 0.044 | 0.000 | 0.000 | true |
| `box` | `large` | 7.470 | 173.560 | 68.000 | 68.000 | 0.000 | 17.150 | 14.617 | -2.533 | 0.852 | 0.250 | 0.204 | 0.001 | 0.000 | true |
| `finance` | `small` | 0.470 | 88.576 | 27.000 | 27.000 | -0.000 | 0.420 | 1.523 | 1.103 | 3.625 | 0.010 | 0.052 | 0.001 | 0.001 | true |
| `finance` | `medium` | 6.410 | 120.135 | 41.000 | 41.000 | -0.000 | 8.590 | 10.041 | 1.451 | 1.169 | 0.190 | 0.222 | 0.006 | 0.004 | true |
| `finance` | `large` | 36.690 | 224.250 | 53.000 | 53.000 | 0.000 | 58.240 | 84.259 | 26.019 | 1.447 | 1.050 | 1.521 | 0.020 | 0.011 | true |
| `rob_est` | `small` | 0.310 | 88.449 | 21.000 | 21.000 | 0.000 | 0.270 | 1.125 | 0.855 | 4.167 | 0.010 | 0.049 | 0.001 | 0.001 | true |
| `rob_est` | `medium` | 4.180 | 116.034 | 25.000 | 25.000 | 0.000 | 4.280 | 5.467 | 1.187 | 1.277 | 0.160 | 0.197 | 0.002 | 0.003 | true |
| `rob_est` | `large` | 23.470 | 212.203 | 29.000 | 29.000 | -0.000 | 23.180 | 36.656 | 13.476 | 1.581 | 0.760 | 1.202 | 0.008 | 0.005 | true |
| `sup_ch` | `small` | 0.100 | 86.435 | 82.000 | 82.000 | -0.000 | 2.410 | 2.910 | 0.500 | 1.207 | 0.000 | 0.007 | 0.023 | 0.025 | true |
| `sup_ch` | `medium` | 0.720 | 88.912 | 77.000 | 77.000 | 0.000 | 9.170 | 10.936 | 1.766 | 1.193 | 0.030 | 0.031 | 0.084 | 0.098 | true |
| `sup_ch` | `large` | 2.540 | 170.184 | 116.000 | 116.000 | -0.000 | 67.080 | 40.296 | -26.784 | 0.601 | 0.150 | 0.114 | 0.375 | 0.191 | true |
