#import "@preview/clean-math-presentation:0.1.1": *

= Results

#slide(title: "Results")[
  == Exemple: Constrained Quadratic Optimal Control
  #align(center)[
    #grid(
      columns: (1fr, 1fr),
      gutter: 2.5em,
      [$ min_(u_t) 1/2 sum_(t=0)^(T-1) (x_t^T Q x_t + u_t^T R u_t) $],
      [
        Our constraints are:

        - $x_(t+1) = A x_t + B u_t$
        - $norm(u_t) <= 1$
      ],
    )
  ]
  
  #pause 
  == Speed control example
  #figure(
    grid(
      columns: 2,
      image("../figures/speed_control_acceleration.png", width: 80%),
      image("../figures/speed_control_velocity.png", width: 80%),
    ),
    caption: "Ratio"
  )

]

#slide(title: "Time comparison")[
  #figure(
image("../figures/c_vs_julia_cold_total.png", width: 80%),
caption: "Execution time of the algorithm for the different problems in the cold-start case."
)
]

#slide(title: "Time comparison proximal operator vs linear")[
  #figure(
  grid(
    columns: 2,
    image("../figures/c_vs_julia_cold_lin.png"),
    image("../figures/c_vs_julia_cold_prox.png")
  ),
  caption: "Execution time of the linear solve (left) and the proximal update (right) for the different problems in the cold-start case."
)
]


