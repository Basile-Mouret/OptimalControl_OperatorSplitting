Optimal control is the task of choosing inputs for a dynamical system so that
the system follows a desired behavior while minimizing a cost. In many
applications, the state of the system (position, inventory, portfolio, etc.)
evolves over time, and each decision affects both the current cost and future
states. This coupling in time is what makes optimal control important and
challenging.

In this project, we study the discrete-time finite-horizon setting. At each
time step $t$, the state $x_t in RR^n$ and control $u_t in RR^m$ are linked by
linear dynamics,

$
	x_(t+1) = A_t x_t + B_t u_t + c_t,
$

with a fixed initial state $x_0 = x_"init"$. \
The objective is to minimize a sum
of stage costs of the form $phi_t(x_t, u_t) + psi_t(x_t, u_t)$ over the full
horizon. In our setting, $phi_t$ is quadratic and smooth, while $psi_t$ is
convex and can represent nonsmooth penalties or constraints (for example box
constraints) through proximal operators.

We focus on the splitting method of O'Donoghue, Stathopoulos, and Boyd @odonoghue2013. The reason is practical: other methods, such as CVX and fast MPC, can solve these problems, but they do not always exploit the time-structure of the
dynamics efficiently,
especially when we need repeated solves. The splitting approach separates the
problem into two parts that are both efficient to compute: a structured
quadratic step with linear dynamics, and a stage-wise proximal step. This gives
an algorithm that is scalable, modular, and well suited to warm starts.

The goal of this work is to reproduce and study this method in a Julia
implementation, using the original C code as reference. We first present the
mathematical formulation and the ADMM-based splitting updates. We then describe
our implementation choices (data structures, factorization cache, and in-place
proximal updates). Finally, we evaluate the solver on the benchmark examples of
the paper, starting with box-constrained quadratic control, and compare
iterations and computation times with the C implementation.