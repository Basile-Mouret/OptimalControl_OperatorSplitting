#import "@preview/clean-math-presentation:0.1.1": *

#slide(title: "Hyperparameter sensitivity")[
  #align(center)[
    #grid(
      columns: 2,
      gutter: 1.2em,
      image("../figures/iterations_vs_reg.png", width: 70%),
      image("../figures/iterations_vs_rho.png", width: 70%),
      grid.cell(colspan: 2)[
        #align(center)[
          #image("../figures/iterations_vs_alpha.png", width: 40%)
        ]
      ],
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
