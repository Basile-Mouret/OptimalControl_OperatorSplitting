#import "@preview/clean-math-presentation:0.1.1": *

#slide(title: "Hyperparameter sensitivity")[
  #align(center)[
    #grid(
      columns: 2,
      gutter: 1.2em,
      image("../figures/iterations_vs_alpha.png"),
      image("../figures/iterations_vs_rho.png"),
    )
  ]
]

#slide(title: "Stopping criterion sensitivity", align: horizon)[
  #align(center)[
    #grid(
      columns: 2,
      gutter: 1.2em,
      image("../figures/iterations_vs_eps_rel.png", width: 96%),
      image("../figures/iterations_vs_eps_abs.png", width: 96%),
    )
  ]
]
