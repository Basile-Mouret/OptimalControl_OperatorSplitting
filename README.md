# Operator Splitting for Optimal Control

Julia reimplementation of the operator-splitting method from
`resources/oper_splt_ctrl.pdf`, using the original C implementation in `osc/`
as the reference.

## References

- paper: `resources/oper_splt_ctrl.pdf`
- reference implementation: `osc/`
- Julia solver: `src/`

## Basic Usage

Build the problem data, create a cache, then solve with a proximal operator.

```julia
using OptimalControl_OperatorSplitting

function prox!(x_tilde, u_tilde, v, w, rho)
    x_tilde .= v
    u_tilde .= w
end

data = all_data(A, B, c, Q, S, R, q, r, x_init;
    rho=50.0,
    alpha=1.8,
    eps_abs=1e-3,
    eps_rel=1e-3,
    reg=1e-6,
)

cache = setup_cache(data)
x, u, tt = solve(cache, prox!; max_iters=3000)

println(tt)
```

The proximal operator must have the signature:

```julia
prox!(x_tilde, u_tilde, v, w, rho)
```

and update `x_tilde` and `u_tilde` in place.

## Cold And Warm Start

The public API is cache-first.

```julia
cache = setup_cache(data)
```

- a fresh cache gives a cold start
- repeated calls to `solve(cache, prox!)` reuse the internal ADMM state and warm start

Example:

```julia
x1, u1, tt1 = solve(cache, prox!; max_iters=3000)  # cold start
x2, u2, tt2 = solve(cache, prox!; max_iters=3000)  # warm start
```

If you want another cold start, build a new cache:

```julia
cache = setup_cache(data)
```

## When A Cache Can Be Reused

You can reuse the same cache while these stay fixed:

- `A`, `B`, `Q`, `S`, `R`
- `rho`, `reg`

You may change without rebuilding the factorization:

- `q`, `r`, `c`, `x_init`

If the structural data changes, build a new cache.

## Problem Data

The solver accepts either:

- time-invariant matrices for `A`, `B`, `Q`, `S`, `R`
- stage-varying 3D arrays for those same quantities

`Q` and `R` are assumed symmetric positive semidefinite.

## Timings

`solve` returns `(x, u, tt)` where `tt` is a `Timings` struct.

Compact output:

```julia
println(tt)
```

Detailed output:

```julia
show(stdout, MIME("text/plain"), tt)
println()
```

## Tests

Run the test suite with:

```bash
julia --project=. test/runtests.jl
```

or:

```julia
pkg> test
```

## Examples

Runnable examples live in `examples/`.

Run them with:

```bash
julia --project=. examples/<example>.jl <size>
```

where `<size>` is one of:

- `small`
- `medium`
- `large`

Examples:

```bash
julia --project=. examples/box_constrained_quadratic_optimal_control.jl small
julia --project=. examples/multiperiod_portfolio_optimization.jl medium
julia --project=. examples/robust_state_estimation.jl large
julia --project=. examples/supply_chain_management.jl small
```
