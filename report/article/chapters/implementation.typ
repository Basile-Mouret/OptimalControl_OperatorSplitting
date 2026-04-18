The implementation aims to provide a high-performance solver through a high-level public interface. Julia is a natural choice for this purpose, as it combines efficient LLVM-based compilation with a dynamic type system.
This makes it well suited to optimization algorithms, which require both a high level of mathematical abstraction and strong performance.
For this project, we used the mature `LinearAlgebra` library, which enables fast implementations of vector and matrix operations.

In order to keep the project clean, we separated the repository into multiple folders.
The main package `OptimalControl_OperatorSplitting` is contained in the `src/` folder. It is split into multiple parts.
In `types.jl` we defined the problem, iterate, cache, and timing structures.
The `utils.jl` file is used for helper functions (constructors, sparse KKT assembly) as well as the convergence metrics.
The main solver logic is then defined in `solver.jl` following the iteration in @admm-steps: it builds the right-hand side of the quadratic step, solves the linear system, applies the optional relaxation, evaluates the stage-wise proximal update @prox-stage, performs the dual update, and checks convergence with the residuals @residuals and the stopping rule @stopping.
Finally `cache.jl` assembles the KKT system @kkt once and computes the sparse $L D L^T$ factorization reused by the solver.
This results in a simple public API, as the user only has to initialise the cache, define the proximal step, and pass it to the solver. For example, for a box-constrained problem:
```julia
function prox!(x_tilde, u_tilde, v, w, rho)
	x_tilde .= v
	u_tilde .= clamp.(w, umin, umax)
end

data = all_data(A, B, c, Q, S, R, q, r, x_init; rho=50.0, alpha=1.8)
cache = setup_cache(data)
x, u, tt = solve(cache, prox!; max_iters=3000)
```
We added some tests comparing the solver against an interior point method `Ipopt.jl` and checked that cache reuse and warm starts remain correct when the linear terms change.
We also implemented the exact examples from the paper in order to compare performance with the `C` implementation.

Because Julia uses a garbage collector to handle memory management, reducing allocations is crucial for performance. We preallocate the ADMM variables and workspaces as vectors, use in-place proximal operators, and rely on the cache to reuse the factorization across iterations and warm-started solves.


