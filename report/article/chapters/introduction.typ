Optimal control is the task of choosing inputs for a dynamical system so that it follows a desired behavior while minimizing a cost. In many applications, the system state (position, inventory, portfolio, etc.) evolves over time, and each decision affects both the current cost and future states. This temporal coupling is what makes optimal control both important and challenging.

In this project, we study the discrete-time finite-horizon setting. At each time step $t$, the state $x_t in RR^n$ and control $u_t in RR^m$ are linked by linear dynamics,

$
	x_(t+1) = A_t x_t + B_t u_t + c_t,
$

with a fixed initial state $x_0 = x_"init"$. The objective is to minimize a sum of stage costs of the form $phi_t (x_t, u_t) + psi_t (x_t, u_t)$ over the full horizon. In our setting, $phi_t$ is quadratic and smooth, while $psi_t$ is convex and can encode nonsmooth penalties or constraints.

We focus on the splitting method of O'Donoghue, Stathopoulos, and Boyd @odonoghue2013 because it exploits the problem structure directly, which makes repeated solves and warm starts efficient. Alternative methods such as CVX, CVXGEN, and fast MPC can also be used for related optimal-control problems, but OSC is especially well suited to our setting. It separates the problem into two efficient steps: a structured quadratic step with linear dynamics and a stage-wise proximal step.

The goal of this work is to reproduce and study this method in Julia, using the original C code as a reference. We first present the mathematical formulation and the ADMM-based splitting updates. We then describe the main implementation choices: data structures, factorization caching, and in-place proximal updates. Finally, we evaluate the solver on the benchmark examples from the paper and compare iteration counts and runtimes with the C implementation.
