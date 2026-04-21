#import "@preview/clean-math-presentation:0.1.1": *

= Method

#slide(title: "Linear-convex optimal control")[
  We consider a finite-horizon problem with linear dynamics and a stage cost
  split into a smooth quadratic part and a convex nonsmooth part.

  $
    min_(x, u) sum_(t=0)^T (phi_t (x_t, u_t) + psi_t (x_t, u_t))
  $

  $
    x_(t+1) = A_t x_t + B_t u_t + c_t, quad t = 0, dots, T - 1,
  $

  with $x_0 = x_"init"$. Here $phi_t$ is quadratic, while $psi_t$ can encode
  nonsmooth penalties or convex constraints.
]

#slide(title: "Why split the problem?")[
  The difficulty is structural. The dynamics couple all stages of the horizon,
  while the terms in $psi$ are separable across time.

  Writing the problem as

  $
    min_(x, u) I_D (x, u) + phi (x, u) + psi (x, u)
  $

  makes this explicit: $I_D$ enforces the dynamics and initial condition,
  whereas $psi$ contains the nonsmooth or constraint-encoding part.

  The idea is then to keep the difficult coupled part together, and isolate the
  part that can be treated stage by stage.
]

#slide(title: "Consensus reformulation")[
  We introduce a copy $(tilde(x), tilde(u))$ of the trajectory and enforce
  equality between the two representations:

  $
    min_(x, u, tilde(x), tilde(u)) I_D (x, u) + phi (x, u) + psi (tilde(x), tilde(u))
  $

  $
    (x, u) = (tilde(x), tilde(u)).
  $

  This does not change the solution. It only separates the objective into two
  blocks, which is exactly what ADMM needs.
]

#slide(title: "ADMM updates")[
  The method alternates between three simple operations:

  $
    (x^(k+1), u^(k+1)) &= arg min_(x, u) I_D (x, u) + phi (x, u) + rho / 2 norm((x, u) - (tilde(x)^k, tilde(u)^k) - (z^k, y^k))_2^2 #linebreak()
    (tilde(x)^(k+1), tilde(u)^(k+1)) &= arg min_(tilde(x), tilde(u)) psi (tilde(x), tilde(u)) + rho / 2 norm((tilde(x), tilde(u)) - (x^(k+1), u^(k+1)) + (z^k, y^k))_2^2 #linebreak()
    (z^(k+1), y^(k+1)) &= (z^k, y^k) + (tilde(x)^(k+1), tilde(u)^(k+1)) - (x^(k+1), u^(k+1)).
  $

  The first line is a quadratic control problem. The second is a proximal step.
  The third is the dual update that enforces consensus.
]

#slide(title: "Why it is efficient")[
  The key point is that the two main subproblems have very different but very
  favorable structures.

  The quadratic step keeps the horizon coupling and is solved through one KKT
  system whose sparse factorization can be cached.

  The proximal step separates across time:

  $
    (tilde(x)_t^(k+1), tilde(u)_t^(k+1)) = "prox"_(psi_t / rho)(x_t^(k+1) - z_t^k, u_t^(k+1) - y_t^k).
  $

  So each stage can be handled independently, often in closed form. This is
  the reason the method is both modular and fast.
]
