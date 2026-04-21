#import "@preview/clean-math-presentation:0.1.1": *

= Method

#slide(title: "Context")[
  We consider a finite-horizon problem with linear dynamics and a stage cost
  split into a smooth quadratic part and a convex nonsmooth part.

      $
        min_(x, u) sum_(t=0)^T (phi_t (x_t, u_t) + psi_t (x_t, u_t))
      $
      $
        "subject to "x_(t+1) = A_t x_t + B_t u_t + c_t, quad t = 0, dots, T - 1, x_0 = x_("init").
      $

  Where $phi_t$ is quadratic and $psi_t$ can encode
  nonsmooth penalties or convex constraints. We respectfully denote $phi(x,u)$ and $psi(x,u)$ the total quadratic/convex cost over time. 

]

#slide(title: "Consensus splitting")[

  We introduce a copy $(tilde(x), tilde(u))$ of the trajectory: 

  $
    min_(x, u, tilde(x), tilde(u)) I_D (x, u) + phi (x, u) + psi (tilde(x), tilde(u))
  #linebreak()
   "subject to" (x, u) = (tilde(x), tilde(u)).
  $

  This does not change the solution. It only separates the objective into two blocks.
  The dynamics stay in the $(x, u)$ block through $I_D$, so the
  $(tilde(x), tilde(u))$ block has no cross-time constraints.

  #pause
  This enables us to solve the problem via ADMM, an algorithm for decomposable optimization problems.
]

#slide(title: "ADMM updates" )[
  The method alternates between three simple operations:

      $
        (x^(k+1), u^(k+1)) &= arg min_(x, u) I_D (x, u) + phi (x, u) + rho / 2 norm((x, u) - (tilde(x)^k, tilde(u)^k) - (z^k, y^k))_2^2 #linebreak()
        (tilde(x)^(k+1), tilde(u)^(k+1)) &= arg min_(tilde(x), tilde(u)) psi (tilde(x), tilde(u)) + rho / 2 norm((tilde(x), tilde(u)) - (x^(k+1), u^(k+1)) + (z^k, y^k))_2^2 #linebreak()
        (z^(k+1), y^(k+1)) &= (z^k, y^k) + (tilde(x)^(k+1), tilde(u)^(k+1)) - (x^(k+1), u^(k+1)).
      $
  The first step is a simple quadratic control problem with linear constraints, and the second one can be rewritten w.r.t the proximal operator. #linebreak()
  Here, $rho$ controls the tradeoff between enforcing $psi$/$phi$ and staying close to the current point.
  #pause
  We can thus solve these two problems independently using the most adequate method for each, justifying the split !
]

#slide(title: "Solving the subproblems")[
  The first subproblem keeps the horizon coupling, but it is purely quadratic
  with linear constraints. After stacking all states and controls, it reduces
  to one structured KKT system:

 
    $
      mat(E, G^T; G, 0) mat(w; lambda) = mat(-f; h).
    $
  #pause
  The second subproblem separates across time : 

    $
      (tilde(x)_t^(k+1), tilde(u)_t^(k+1)) = "prox"_(psi_t / rho)(x_t^(k+1) - z_t^k, u_t^(k+1) - y_t^k).
    $
 In many cases, the evaluation of the proximal operator  is available in closed form.
]
