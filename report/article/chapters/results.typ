== Performance comparison

To evaluate our implementation, we used the same benchmark problems, problem
parameters, and convergence criterion as the reference paper. With this setup,
we obtain exactly the same number of iterations to convergence as the original
C implementation, for the same solutions, on every problem variant reported in
the paper. This is a strong validation that the Julia solver faithfully
reproduces the reference algorithm.

In terms of runtime, the Julia implementation remains in the same overall order
of magnitude as the C code. #figure(
image("../figures/c_vs_julia_cold_total.png", width: 80%),
caption: "Execution time of the algorithm for the different problems in the cold-start case."
)

Each iteration is split into two main steps: the linear-system solve and the
proximal update. We therefore measured them separately to identify the source
of the runtime differences.

#figure(
  grid(
    columns: 2,
    image("../figures/c_vs_julia_cold_lin.png"),
    image("../figures/c_vs_julia_cold_prox.png")
  ),
  caption: "Execution time of the linear solve (left) and the proximal update (right) for the different problems in the cold-start case."
)

We can see that Julia is slower on the linear solve but faster on the
proximal step. The slower linear solve is mainly explained by memory
allocations, which are more costly in Julia than in the reference C code.

The exact problem structure matters: when the
proximal step is relatively expensive compared with the linear solve, Julia can
be faster overall, as in the supply-chain example; on less favorable problems,
it is slightly slower. Overall, the goal of high performance is achieved even
relative to this low-level C implementation.


