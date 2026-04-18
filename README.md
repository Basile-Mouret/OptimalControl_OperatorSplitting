# Operator Splitting for Optimal Control

A Julia package for solving optimal control problems efficiently.

Based on: [Operator Splitting for Optimal Control](https://stanford.edu/~boyd/papers/pdf/oper_splt_ctrl.pdf) 
by Brendan O'Donoghue, George Stathopoulos and Stephen Boyd.

Freely inspired by the existing [C implementation](https://github.com/cvxgrp/osc) of the same algorithm.

## What does this solve ?

$$
\begin{aligned}
\min_{\substack{x_t, u_t \\ t=0,\ldots,T}} \quad &
\sum_{t=0}^{T} \left( \phi_t(x_t, u_t) + \psi_t(x_t, u_t) \right) \\
\text{subject to} \quad &
x_{t+1} = A_t x_t + B_t u_t + c_t,\quad t=0,\ldots,T-1.
\end{aligned}
$$

Where the $\phi_t$ terms are quadratic and the $\psi_t$ terms are arbitrary, supplied by the user in the form of a proximal operator.

## Usage

#### Problem Data

```julia
data = all_data(A, B, c, Q, S, R, q, r, x_init;
    rho=50.0,
    alpha=1.8,
    eps_abs=1e-3,
    eps_rel=1e-3,
    reg=1e-6,
)
```

See [`src/types.jl`](src/types.jl) for guidelines on variable types.

#### Proximal operator

The proximal operator must have the signature:

```julia
prox!(x_tilde, u_tilde, v, w, rho)
```

and update `x_tilde` and `u_tilde` in place.

#### Cache

Before solving, one must build a cache from the problem data.

```julia
cache = setup_cache(data)
```

Repeated calls to the solver with the same cache will reuse the internal problem state, thus resulting in a "warm start" of the resolution, yielding a noticeable performance increase.

You can reuse the same cache while these stay fixed:

- `A`, `B`, `Q`, `S`, `R`
- `rho`, `reg`

Equivalently, you can freely change these variables without rebuilding the cache:

- `q`, `r`, `c`, `x_init`

#### Solver

```julia
x, u, tt = solve(cache, prox!; max_iters=3000)
```

The `tt` output is a `Timings` struct which contains the timing logs of the solver run.

```julia
# Compact output
println(tt)

# Detailed output
display(tt)
```

## Examples

Runnable examples (from [Operator Splitting for Optimal Control](https://stanford.edu/~boyd/papers/pdf/oper_splt_ctrl.pdf)) live in [`examples/`](examples/).
You can run them by specifying the problem size (small, medium, large).
