# Architecture

## Reference Order

When changing the solver, use these references in this order:

1. `resources/oper_splt_ctrl.pdf`
2. `osc/`
3. `src/`

The paper and the C code are the source of truth.

## Source Layout

- `src/OptimalControl_OperatorSplitting.jl`: package entry point and exports
- `src/types.jl`: core structs (`all_data`, `prob_vars`, `solver_cache`, `Timings`)
- `src/utils.jl`: constructors, timing helpers, convergence helpers, KKT assembly
- `src/cache.jl`: cache construction and fixed RHS refresh
- `src/solver.jl`: public solve API and ADMM loop
- `examples/`: runnable example scripts
- `test/`: test suite

## Solver Structure

The public workflow is:

```julia
data = all_data(...)
cache = setup_cache(data)
x, u, tt = solve(cache, prox!; max_iters=...)
```

Design choices:

- `all_data` stores problem data and solver parameters
- `solver_cache` stores the KKT factorization, work buffers, and internal ADMM state
- a fresh cache gives a cold start
- repeated `solve(cache, ...)` calls warm start automatically

The cache is valid while these stay fixed:

- `A`, `B`, `Q`, `S`, `R`
- `rho`, `reg`

Changing `q`, `r`, `c`, or `x_init` is allowed without rebuilding the factorization.

## Internal Split

The solver loop in `src/solver.jl` is intentionally small.

Helpers that are not the ADMM loop itself live in `src/utils.jl`, including:

- stage access helpers
- timing helpers
- convergence metrics
- triplet-based KKT assembly

## Testing

Run all tests with:

```bash
julia --project=. test/runtests.jl
```

or:

```julia
pkg> test
```

Current test files:

- `test/basic.jl`: basic solver behavior
- `test/reference_solutions.jl`: comparison against small Ipopt solves
- `test/cache_and_warm_start.jl`: cache reuse and warm-start semantics
- `test/support.jl`: shared fixtures and helper functions

## Testing Guidelines

Keep tests focused on important behavior, not tiny implementation details.

Prioritize:

- solver correctness on small direct-reference problems
- convergence behavior
- cache reuse correctness
- warm-start behavior
- regressions in the public API

Prefer readable test fixtures over clever abstractions.

## Contributor Notes

- match algorithmic behavior to the C implementation unless there is a clear Julia-specific improvement
- keep changes minimal
- optimize hot paths, not one-off setup code
- avoid adding abstractions unless they simplify the code materially
