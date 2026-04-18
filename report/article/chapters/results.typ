== Performance comparison

To evaluate our implementation, we used the same examples as in the paper and compared our results with those of the reference C implementation. The main validation result is that we obtain the same number of iterations to convergence. This shows that the Julia solver reproduces the behavior of the original method.

#let data = csv("../results/c_vs_julia_cold.csv")
#let filtered-data = data.map(row => (row.at(0), row.at(1), row.at(2), row.at(3), ))
#set text(hyphenate: true)

#figure(
table(
  columns: filtered-data.first().len(),
  
  fill: (col, row) => if row == 0 or col == 0 { luma(240) } else { white },
  ..filtered-data.flatten()
),
caption: "Number of iterations to converge for the cold start case."
)

Execution times, however, differ. For some problems our implementation is faster than the C version, while for others it is slower.

#figure(
image("../figures/c_vs_julia_cold_total.png", width: 80%),
caption: "Execution time of the algorithm for the different problems in the cold-start case."
)

Each iteration is split into two main steps: the linear-system solve and the proximal update. We therefore measured these two parts separately to identify the source of the runtime differences.

#figure(
  grid(
    columns: 2,
    image("../figures/c_vs_julia_cold_lin.png"),
    image("../figures/c_vs_julia_cold_prox.png")
  ),
  caption: "Execution time of the linear solve (left) and the proximal update (right) for the different problems in the cold-start case."
)

The plots show that our implementation is slower on the linear solve but faster on the proximal step. A likely explanation is that the linear solve is more sensitive to memory allocation and data movement, which are more costly in Julia than in the reference C code.
