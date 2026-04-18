We chose Julia to combine a higher level of abstraction with performance close to the original C implementation. Its syntax makes numerical code readable, and its REPL is convenient for experimentation. Compared with Python, Julia has a smaller ecosystem, but for optimization and scientific computing the necessary libraries are available. In this project, we mainly relied on the standard `LinearAlgebra` library for matrix operations and factorizations.

To keep the project organized, we separated the repository into several folders.
The main package, `OptimalControl_OperatorSplitting`, is contained in `src/` and split across several files.
In `types.jl` we defined the problem, iterate, cache, and timing structures.
The `utils.jl` file is used for helper functions (constructors, sparse KKT assembly) as well as the convergence metrics.
The main solver logic is then defined in `solver.jl` following the iteration in @admm-steps: it builds the right-hand side of the quadratic step, solves the linear system, applies the optional relaxation, evaluates the stage-wise proximal update @prox-stage, performs the dual update, and checks convergence with the residuals @residuals and the stopping rule @stopping.
Finally, `cache.jl` assembles the KKT system @kkt once and computes the sparse $L D L^T$ factorization reused by the solver.
This yields a simple public API: the user initializes the cache, defines the proximal step, and passes it to the solver. For a box-constrained problem:
```julia
function prox!(x_tilde, u_tilde, v, w, rho)
	x_tilde .= v
	u_tilde .= clamp.(w, umin, umax)
end

data = all_data(A, B, c, Q, S, R, q, r, x_init; rho=50.0, alpha=1.8)
cache = setup_cache(data)
x, u, tt = solve(cache, prox!; max_iters=3000)
```
We added tests comparing the solver against the interior-point solver `Ipopt.jl` and checked that cache reuse and warm starts remain correct when the linear terms change.

We also implemented the examples from the paper to compare our performance with the C implementation.

Because Julia uses garbage collection, reducing allocations is important for performance. We therefore preallocate the ADMM variables and workspaces, use in-place proximal operators, and reuse the cached factorization across iterations and warm-started solves.
