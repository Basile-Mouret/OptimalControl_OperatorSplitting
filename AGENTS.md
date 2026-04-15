# AGENTS.md

## Project Purpose

This repository reimplements the operator splitting method for finite-horizon optimal control in Julia.

The immediate project goal is to reproduce all examples from the original paper in Julia, while keeping the code:
- minimal
- readable
- optimized where it matters

## Authoritative References

Always use these in this order:

1. Original paper:
   `resources/oper_splt_ctrl.pdf`
2. Original C implementation:
   `osc/`
3. Current Julia implementation:
   `src/`

The paper and the C code are the source of truth.

If there is any ambiguity in the Julia code, do not guess. Check the paper and the C implementation.

## Important Rule

Always use the C implementation as the reference implementation.

That means:
- match the algorithmic structure to `osc/src/`
- match the example-specific proximal logic to the corresponding example folder in `osc/`
- match stopping logic, parameter meanings, and data layout to the C code unless there is a deliberate Julia-specific improvement

## Where Important Context Lives

### Paper
- `resources/oper_splt_ctrl.pdf`

This defines:
- the optimization problem
- the ADMM / operator-splitting algorithm
- the residual-based stopping criterion
- the benchmark examples

### C Reference Implementation
- generic solver core: `osc/src/`
- example-specific logic:
  - `osc/box/`
  - `osc/finance/`
  - `osc/rob_est/`
  - `osc/sup_ch/`

Important C files:
- `osc/src/osc.c`
- `osc/src/osc.h`
- `osc/src/run_osc.c`

Important example files:
- each example's `src/prox.c`
- each example's `gen_data.m`

### Julia Implementation
- package entry point: `src/OptimalControl_OperatorSplitting.jl`
- problem data and core types: `src/types.jl`, `src/utils.jl`
- cache and factorization setup: `src/cache.jl`
- solver loop and KKT assembly: `src/solver.jl`
- runnable examples: `examples/`

## Current Julia Design

The Julia package core is solver-only.

Do not put paper-example-specific problem logic into `src/`.

Example logic belongs in `examples/`.

Current important API:

```julia
data = all_data(A, B, c, Q, S, R, q, r, x_init; rho=..., alpha=..., eps_abs=..., eps_rel=..., reg=...)
cache = setup_cache(data)

x, u, tt = solve(cache, prox!; max_iters=...)
```

Notes:
- a fresh cache gives a cold start
- repeated calls to `solve(cache, ...)` reuse the internal ADMM state and warm start
- building a new cache is the way to force a fresh cold start

## Current Solver Assumptions

- stage-varying data is supported for `A`, `B`, `Q`, `S`, `R`
- `Q` and `R` are symmetric positive semidefinite
- the cache is valid only while `A`, `B`, `Q`, `S`, `R`, `rho`, and `reg` stay fixed
- `q`, `r`, `c`, and `x_init` may change without rebuilding the factorization

## Coding Guidelines

### Main Principles

Optimize for this order:

1. correctness
2. readability
3. minimality
4. performance in the hot path

Prefer the smallest correct change.

Do not introduce abstraction just because it is possible.

Keep code easy to read for someone cross-checking it against the paper and the C implementation.

### Minimal

- do not add compatibility wrappers unless explicitly needed
- do not add unnecessary helper layers
- do not add framework-like abstractions
- prefer one clear function over many tiny indirect ones

### Readable

- use names that match the paper / C implementation when practical
- keep control flow obvious
- keep mathematical structure recognizable
- add comments only when they explain something non-obvious

### Optimized

Optimize the actual hot paths, not setup code that runs once.

Important performance rules for this repo:
- preallocate solve buffers
- use `ldiv!`
- use cached factorizations
- avoid per-iteration allocations
- avoid sparse matrix mutation during assembly
- build sparse matrices in one shot using triplets
- use matrix norms and linear algebra utilities idiomatically if they are allocation-free after warm-up

## What To Validate After Changes

When changing solver logic, validate against at least one small direct solve.

Preferred checks:
- compare unconstrained cases against a direct convex solve on a tiny problem
- compare constrained cases against a small Ipopt model when practical
- check that residuals decrease and convergence status is sensible
- check that warm-start reuses `vars` and `cache` correctly

## Example Policy

Examples belong in `examples/`.

Examples should:
- be runnable directly
- not execute automatically when merely included
- print useful outputs such as timings
- use the package API, not duplicate solver internals

## What Not To Do

- do not treat the current Julia implementation as the final reference
- do not invent behavior when the paper/C code already specifies it
- do not add heavy dependencies to the package core without a strong reason
- do not hide the algorithm behind unnecessary abstractions
- do not optimize away readability for tiny gains unless the code is on the hot path

## Near-Term Goal

Port and validate all paper examples:
- `box`
- `finance`
- `rob_est`
- `sup_ch`

Each new example should stay faithful to the paper and the C code, and should use the solver core in `src/` rather than reimplementing it.
