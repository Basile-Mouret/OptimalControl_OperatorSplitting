#set math.equation(numbering: "(1)", supplement: [Eq.])

The Julia solver implemented in this project follows the operator-splitting
method proposed by O'Donoghue, Stathopoulos, and Boyd @odonoghue2013 for
finite-horizon linear-convex optimal control. The presentation below mirrors
the paper's formulation and isolates the two computational primitives used in
the implementation: a structured quadratic control solve and a stage-wise
proximal update.

== Problem Formulation

For a horizon $T$, let $x_t in RR^n$ and $u_t in RR^m$ denote the state and
control at stage $t$. We consider the finite-horizon problem

$
  min_(x, u) sum_(t=0)^T (phi_t (x_t, u_t) + psi_t (x_t, u_t))
$ <ocp>

subject to the dynamics $x_(t+1) = A_t x_t + B_t u_t + c_t$ for
$t = 0, dots, T - 1$, and $x_0 = x_"init"$.

The quadratic part of the stage cost is

$
  phi_t (x, u) = 1 / 2 x^T Q_t x + x^T S_t u + 1 / 2 u^T R_t u + q_t^T x + r_t^T u,
$

with a positive-semidefinite block matrix $mat(Q_t, S_t; S_t^T, R_t)$. The
term $psi_t$ is assumed to be closed, proper, and convex; by allowing
extended values, it can also encode convex constraints through indicator
functions. Over the whole horizon, define

$
  phi (x, u) = sum_(t=0)^T phi_t (x_t, u_t), quad
  psi (x, u) = sum_(t=0)^T psi_t (x_t, u_t),
$

and let $D$ be the affine set of trajectories satisfying the dynamics and the
initial condition,

$
  D = { (x, u) | x_0 = x_"init", x_(t+1) = A_t x_t + B_t u_t + c_t,
  t = 0, dots, T - 1 }.
$ <initial-cond>

We denote by $I_D$ the indicator function of this set,

$
  I_D (x, u) = cases(
    0 "if" (x, u) in D,
    +infinity "otherwise"
  ).
$

The role of $I_D $ is to enforces feasibility.
The optimal control problem can then be written compactly as

$
  min_(x, u) I_D (x, u) + phi (x, u) + psi (x, u).
$ <compact>

This decomposition is chosen so that the
quadratic part and the linear dynamics remain grouped together, while the
nonsmooth or constraint-encoding terms remain separate.

== Consensus Splitting

To split these two parts algorithmically, we introduce auxiliary variables
$(tilde(x), tilde(u))$ as a copy of the trajectory and write the problem as:

$
  min_(x, u, tilde(x), tilde(u))
  I_D (x, u) + phi (x, u) + psi (tilde(x), tilde(u))
$ <consensus>

subject to $(x, u) = (tilde(x), tilde(u))$.

The consensus constraint $(x, u) = (tilde(x), tilde(u))$ forces the original variables and their copy to coincide componentwise at a
solution. 

Applying scaled ADMM with penalty parameter $rho > 0$ and scaled dual
variables $(z, y)$ gives the iteration

$
  (x^(k+1), u^(k+1)) &= arg min_(x, u) I_D (x, u) + phi (x, u) + rho / 2 norm((x, u) - (tilde(x)^k, tilde(u)^k) - (z^k, y^k))_2^2 #linebreak()
  (tilde(x)^(k+1), tilde(u)^(k+1)) &= arg min_(tilde(x), tilde(u)) psi (tilde(x), tilde(u)) + rho / 2 norm((tilde(x), tilde(u)) - (x^(k+1), u^(k+1)) + (z^k, y^k))_2^2 #linebreak()
  (z^(k+1), y^(k+1)) &= (z^k, y^k) + (tilde(x)^(k+1), tilde(u)^(k+1)) - (x^(k+1), u^(k+1)).
$ <admm-steps>


The second update separates across time because
$psi (tilde(x), tilde(u)) = sum_(t=0)^T psi_t (tilde(x)_t, tilde(u)_t)$. Thus,
for each stage $t$:

$
  (tilde(x)_t^(k+1), tilde(u)_t^(k+1)) = arg min_(macron(x), macron(u))
  psi_t (macron(x), macron(u))
  + rho / 2 norm((macron(x), macron(u))
  - (x_t^(k+1) - z_t^k, u_t^(k+1) - y_t^k))_2^2,
$ <prox-stage>

which is precisely the proximal operator of $psi_t / rho$ evaluated at
$(x_t^(k+1) - z_t^k, u_t^(k+1) - y_t^k)$. 

The first update is a convex quadratic optimal control problem with linear
dynamics. 

This justifies the splitting idea of the method : the only horizon-coupled step is quadratic, while the nonsmooth
part reduces to independent small problems that can often be solved in closed
form.

== Quadratic Step 

Define the stacked primal variable
$w = (x_0, u_0, x_1, u_1, dots, x_T, u_T)$.

For each stage $t$, define

$
  E_t = mat(Q_t + rho I, S_t; S_t^T, R_t + rho I).
$

Since $mat(Q_t, S_t; S_t^T, R_t)$ is positive semidefinite and $rho > 0$,
each matrix $E_t$ is symmetric positive definite. 
Let $E$ be the block diagonal matrix with diagonal blocks $E_0, dots, E_T$.
Let $h$ denote the RHS constraints vector and $f$ denote the linear objective vector :

$
  h &= (x_"init", c_0, c_1, dots, c_(T-1)) #linebreak()
  f &= (
    q_0 - rho (tilde(x)_0^k + z_0^k),
    r_0 - rho (tilde(u)_0^k + y_0^k),
    dots,
    q_T - rho (tilde(x)_T^k + z_T^k),
    r_T - rho (tilde(u)_T^k + y_T^k)
  )
$

Finally, let $G$ be the block-sparse linear operator such that $G w = h$ is
equivalent to the initial conditions (@initial-cond).
With these definitions, the quadratic step of (@admm-steps) is equivalent, after expanding
the squared norm and dropping terms independent of $w$, to the quadratic
program

$
  min_w 1 / 2 w^T E w + f^T w
$ <qp>

subject to $G w = h$.

The associated optimality conditions are
the KKT system

$
  mat(E, G^T; G, 0) mat(w; lambda) = mat(-f; h).
$ <kkt>

For fixed $A_t$, $B_t$, $Q_t$, $S_t$, $R_t$, and $rho$, the matrix in @kkt is
constant across ADMM iterations. The implementation therefore factorizes this
matrix once by a sparse $L D L^T$ factorization and reuses the factorization
throughout a solve, and also across warm-started solves whenever the
structural data stay unchanged.

== Convergence Criterion
Convergence is monitored through the primal and dual residuals associated with
the consensus constraint @consensus:

$
  r^k = (x^k, u^k) - (tilde(x)^k, tilde(u)^k), quad
  s^k = rho ((tilde(x)^k, tilde(u)^k) - (tilde(x)^(k-1), tilde(u)^(k-1))).
$ <residuals>

The algorithm stops when both residual norms are sufficiently small,

$
  norm(r^k)_2 <= epsilon_"pri" quad "and" quad norm(s^k)_2 <= epsilon_"dual",
$ <stopping>

with thresholds

$
  epsilon_"pri" = epsilon_"abs" sqrt((T + 1)(n + m))
  + epsilon_"rel" max(norm((x^k, u^k))_2, norm((tilde(x)^k, tilde(u)^k))_2),
$

$
  epsilon_"dual" = epsilon_"abs" sqrt((T + 1)(n + m))
  + epsilon_"rel" norm((z^k, y^k))_2.
$

Following @odonoghue2013, one may also use relaxation by replacing
$(x^(k+1), u^(k+1))$ in the proximal and dual updates with

$
  alpha (x^(k+1), u^(k+1)) + (1 - alpha) (tilde(x)^k, tilde(u)^k),
  quad alpha in (0, 2),
$

which often improves empirical convergence.
