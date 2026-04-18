== Performance comparison

For testing our implementation we used the same exemple as in the paper to compare our results with the ones obtained by the authors. The most important thing is that we obtained the same number of iterations to converge. That shows that our implementation is correct and that we are able to reproduce the results of the paper, that were made using C.

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

However, for the time of execution, we obtained different results. For some problems out implementation is faster than the one in C, and for some others it is slower.

#figure(
image("../figures/c_vs_julia_cold_total.png", width: 80%),
caption: "Time of execution of the algorithm for the different problems in the cold start case."
)

To explain this difference, we need to understand that our problem resolution is separated in two steps: the linear par with the gradient, and the application of the proximal operator. We decide then to compare the time of execution of these two steps separately, to see if we can find where the difference comes from.

#figure(
  grid(
    columns: 2,
    image("../figures/c_vs_julia_cold_lin.png"),
    image("../figures/c_vs_julia_cold_prox.png")
  ),
  caption: "Time of execution of the linear solver (left) and the proximal operator (right) for the different problems in the cold start case."
)

We can see that for the linear part, our implementation is slower than the one in C, while for the proximal operator, our implementation is faster. This can be explained by the fact that for the linear part there is a lot of memory allocation and deallocation, which can be costly in terms of time for Julia.

