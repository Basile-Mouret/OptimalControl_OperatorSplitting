#import "@preview/clean-math-presentation:0.1.1": *

= Implementation

== Julia Implementation

#grid(
  columns: (0.8fr, 1.2fr),
  column-gutter: 18pt,
  [
      #image("../figures/Julia_Programming_Language_Logo.png", width: 60%)

    #v(0.9em)

      - Designed for scientific computing
      - High-level syntax
      - Just-in-time compiled
  ],
  [
    #strong[Solver API]

    #block(
      inset: 10pt,
      radius: 10pt,
      fill: rgb("#f6f6f2"),
      stroke: rgb("#d8d8d0"),
    )[
      #set text(size: 17pt)
      ```julia
using LinearAlgebra
using OptimalControl_OperatorSplitting

function prox!(x_tilde, u_tilde, v, w, rho)
    x_tilde .= v
    u_tilde .= clamp.(w, umin, umax)
end

data = all_data(A, B, c, Q, S, R, q, r, x_init)

cache = setup_cache(data)

x, u, tt = solve(cache, prox!; max_iters=3000)
```
    ]
  ],
)
