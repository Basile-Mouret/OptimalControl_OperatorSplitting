# Resources

This folder collects the main paper for the project together with supporting references on:

- rigorous optimal control theory;
- geometric control and Hamiltonian viewpoints;
- numerical optimal control;
- proximal, ADMM, and operator-splitting methods;
- implementation guidance for MPC and embedded optimization.

The filenames are normalized for easier lookup.

## Main Paper

- `oper_splt_ctrl.pdf` - O'Donoghue, Stathopoulos, and Boyd, *A Splitting Method for Optimal Control*. The core project reference: discrete-time linear-convex optimal control solved by splitting a quadratic dynamics-constrained step and a per-stage proximal step.

## Foundations

- `foundations/evans_mathematical_optimal_control.pdf` - Evans, *An Introduction to Mathematical Optimal Control Theory*. A rigorous and approachable entry point for PMP, dynamic programming, and HJB.
- `foundations/liberzon_calculus_variations_optimal_control.pdf` - Liberzon, *Calculus of Variations and Optimal Control Theory*. Concise graduate-level treatment of calculus of variations, PMP, HJB, and LQ control.
- `foundations/sontag_mathematical_control_theory.pdf` - Sontag, *Mathematical Control Theory*. Broad, rigorous control-theory foundation with strong emphasis on precise statements and proofs.
- `foundations/agrachev_geometry_of_optimal_control_problems_hamiltonian_systems.pdf` - Agrachev, *Geometry of Optimal Control Problems and Hamiltonian Systems*. One of the best geometric/Hamiltonian references for deep intuition.
- `foundations/agrachev_sachkov_control_theory_geometric_viewpoint.pdf` - Agrachev and Sachkov, *Control Theory from the Geometric Viewpoint*. Broader geometric control background: Lie brackets, reachable sets, and geometric methods.
- `foundations/sachkov_introduction_to_geometric_control.pdf` - Sachkov, *Introduction to Geometric Control*. Shorter and more modern introduction to the geometric viewpoint.
- `foundations/karabash_geometric_optimal_control_notes.pdf` - Karabash lecture notes on geometric optimal control. A lighter course-note path into geometric ideas and examples.
- `foundations/kohn_brief_introduction_optimal_control_hjb.pdf` - Kohn notes, *A Brief Introduction to Optimal Control*. Very short refresher on dynamic programming and the Hamilton-Jacobi-Bellman equation.
- `foundations/rawlings_mayne_diehl_mpc_2ed.pdf` - Rawlings, Mayne, and Diehl, *Model Predictive Control: Theory, Computation, and Design*. Standard reference for discrete-time constrained optimal control and MPC.
- `foundations/diehl_gros_numerical_optimal_control_draft.pdf` - Diehl and Gros, *Numerical Optimal Control* draft. Up-to-date numerical OCP reference with strong implementation relevance.
- `foundations/diehl_bock_schloeder_optimal_control_estimation_notes.pdf` - Diehl, Bock, and Schloeder lecture notes on optimal control and estimation. Good numerical perspective on transcription, sensitivities, and algorithms.
- `foundations/rao_survey_numerical_methods_optimal_control.pdf` - Rao, *A Survey of Numerical Methods for Optimal Control*. Compact map of direct vs. indirect methods and discretization choices.

## Implementation

- `implementation/boyd_parikh_proximal_algorithms.pdf` - Parikh and Boyd, *Proximal Algorithms*. Core reference for proximal operators, envelopes, splitting templates, and practical operator calculus.
- `implementation/boyd_et_al_admm_distributed_optimization.pdf` - Boyd, Parikh, Chu, Peleato, and Eckstein, *Distributed Optimization and Statistical Learning via ADMM*. Canonical ADMM survey.
- `implementation/eckstein_yao_understanding_convergence_admm.pdf` - Eckstein and Yao, *Understanding the Convergence of ADMM*. More theoretical convergence perspective than the standard ADMM survey.
- `implementation/giselsson_boyd_linear_convergence_dr_admm.pdf` - Giselsson and Boyd, *Linear Convergence and Metric Selection for Douglas-Rachford Splitting and ADMM*. Important for parameter scaling and rate intuition.
- `implementation/wohlberg_admm_penalty_parameter_selection.pdf` - Wohlberg, *ADMM Penalty Parameter Selection by Residual Balancing*. Practical cautionary note on rho tuning.
- `implementation/xu_figueiredo_goldstein_adaptive_admm.pdf` - Xu, Figueiredo, and Goldstein, *Adaptive ADMM with Spectral Penalty Parameter Selection*. Useful modern adaptive-rho heuristic.
- `implementation/stathopoulos_et_al_operator_splitting_methods_in_control.pdf` - Stathopoulos et al., *Operator Splitting Methods in Control*. The closest survey to this project's algorithmic niche.
- `implementation/jones_operator_splitting_fast_mpc_slides.pdf` - Jones, *Operator Splitting Methods for Fast MPC* slides. Fast overview of how splitting ideas are used in MPC.
- `implementation/stellato_et_al_osqp_operator_splitting_qp.pdf` - Stellato et al., *OSQP: an Operator Splitting Solver for Quadratic Programs*. Relevant when the quadratic subproblem is cast as a structured QP.
- `implementation/verschueren_et_al_acados_fast_embedded_optimal_control.pdf` - Verschueren et al., *acados: a modular open-source framework for fast embedded optimal control*. Software and solver-engineering perspective.
- `implementation/krupa_mpc_embedded_first_order_methods.pdf` - Krupa, *Implementation of MPC in Embedded Systems Using First Order Methods*. Detailed implementation caveats for first-order MPC solvers.
- `implementation/ferreau_embedded_optimization_methods_industrial_control.pdf` - Ferreau et al., *Embedded Optimization Methods for Industrial Automatic Control*. Survey of industrial deployment concerns and solver tradeoffs.
- `implementation/combettes_geometry_of_monotone_operator_splitting.pdf` - Combettes, *The Geometry of Monotone Operator Splitting Methods*. A modern geometric framework for understanding splitting algorithms themselves.

## Suggested Reading Routes

### For rigorous optimal control theory

1. Evans
2. Liberzon
3. Sontag

### For geometric intuition

1. Sachkov introduction
2. Agrachev Hamiltonian notes
3. Agrachev-Sachkov geometric control book

### For numerical optimal control and MPC

1. Rawlings-Mayne-Diehl
2. Diehl-Gros
3. Rao survey

### For the splitting method in `oper_splt_ctrl.pdf`

1. Parikh-Boyd proximal algorithms
2. Boyd et al. on ADMM
3. Stathopoulos et al. on operator splitting in control
4. Giselsson-Boyd on convergence and metric selection
5. OSQP / acados / Krupa for implementation practice

## Paper-Centric Reading Plan

Use this route if the main goal is to understand `oper_splt_ctrl.pdf` deeply enough to implement it carefully.

1. Read `oper_splt_ctrl.pdf` once straight through just to identify the objects: state, control, horizon, stage costs, duplicated variables, and the two alternating subproblems.
2. For the problem formulation, read `foundations/rawlings_mayne_diehl_mpc_2ed.pdf` together with `foundations/liberzon_calculus_variations_optimal_control.pdf`. This gives the clean finite-horizon optimal-control background behind the paper's discrete-time linear-convex setup.
3. For deeper mathematical intuition, especially why the quadratic subproblem still has rich control structure, read `foundations/evans_mathematical_optimal_control.pdf` and `foundations/sontag_mathematical_control_theory.pdf`.
4. For geometric and Hamiltonian intuition, read `foundations/agrachev_geometry_of_optimal_control_problems_hamiltonian_systems.pdf`, then `foundations/sachkov_introduction_to_geometric_control.pdf`, and then `foundations/agrachev_sachkov_control_theory_geometric_viewpoint.pdf` if you want more depth.
5. Before re-reading the paper's proximal step, study `implementation/boyd_parikh_proximal_algorithms.pdf`. Focus on proximal maps, indicator functions, separability, and why the per-time-step nonsmooth step can often be solved in closed form.
6. Before re-reading the consensus reformulation and ADMM iteration, study `implementation/boyd_et_al_admm_distributed_optimization.pdf` and `implementation/stathopoulos_et_al_operator_splitting_methods_in_control.pdf`. This makes the variable splitting and agreement constraints feel much more natural.
7. For the quadratic control subproblem, use `foundations/diehl_gros_numerical_optimal_control_draft.pdf`, `foundations/diehl_bock_schloeder_optimal_control_estimation_notes.pdf`, and `foundations/rao_survey_numerical_methods_optimal_control.pdf`. These explain how structure is exploited numerically.
8. For solver design and what the quadratic step looks like in modern software, read `implementation/stellato_et_al_osqp_operator_splitting_qp.pdf`, `implementation/verschueren_et_al_acados_fast_embedded_optimal_control.pdf`, and `implementation/krupa_mpc_embedded_first_order_methods.pdf`.
9. Only after the algorithm itself is clear, read `implementation/giselsson_boyd_linear_convergence_dr_admm.pdf`, `implementation/eckstein_yao_understanding_convergence_admm.pdf`, `implementation/wohlberg_admm_penalty_parameter_selection.pdf`, and `implementation/xu_figueiredo_goldstein_adaptive_admm.pdf`. These are best used to understand tuning, scaling, and convergence behavior rather than as first exposure.
10. Finish by re-reading `oper_splt_ctrl.pdf` and annotating each equation with the Julia routine or data structure that would implement it.

## Further Reading: Newer Implementations and Alternative Approaches

These are useful when you want to move beyond the exact algorithm in `oper_splt_ctrl.pdf`. They are not uniformly better; the right choice depends on convexity, smoothness, conditioning, horizon length, and whether you care more about very fast moderate accuracy or stronger high-accuracy solves.

- `implementation/combettes_geometry_of_monotone_operator_splitting.pdf` - modern geometric view of operator splitting beyond the standard ADMM story.
- `implementation/stellato_et_al_osqp_operator_splitting_qp.pdf` - strong modern baseline for sparse convex QPs solved by operator splitting.
- `implementation/verschueren_et_al_acados_fast_embedded_optimal_control.pdf` - good entry point into a current embedded optimal-control software stack.
- `implementation/krupa_mpc_embedded_first_order_methods.pdf` - practical discussion of when first-order methods are attractive and where they become limiting.
- `implementation/ferreau_embedded_optimization_methods_industrial_control.pdf` - broad survey of solver tradeoffs in real industrial deployments.

Additional references worth adding later if the project expands:

- Frison and Diehl, *HPIPM: a high-performance quadratic programming framework for model predictive control*, IFAC-PapersOnLine 53(2), 2020, arXiv:2003.02547. Useful when the structured quadratic step is better handled by a high-performance interior-point method.
- Andersson, Gillis, Horn, Rawlings, and Diehl, *CasADi: a software framework for nonlinear optimization and optimal control*, Mathematical Programming Computation 11, 2019. Important if the project moves toward nonlinear models, automatic differentiation, or code generation.
- Stella, Themelis, Sopasakis, and Patrinos, *A Simple and Efficient Algorithm for Nonlinear Model Predictive Control*, CDC 2017, arXiv:1709.06487. PANOC-based alternative for embedded nonlinear MPC.
- Diehl, Bock, and Schloeder, *A Real-Time Iteration Scheme for Nonlinear Optimization in Optimal Feedback Control*, SIAM Journal on Control and Optimization 43(5), 2005. Classic RTI/SQP route for fast nonlinear MPC.
- Schwan, Jiang, Kuhn, and Jones, *PIQP: A Proximal Interior-Point Quadratic Programming Solver*, arXiv:2304.00290, 2023. Modern hybrid proximal/interior-point QP solver.

Rough rule of thumb:

- For convex QPs where fast moderate accuracy is enough, operator splitting remains very attractive.
- For higher-accuracy QP solves with strong structure, interior-point or structure-exploiting Riccati-based solvers may be preferable.
- For nonlinear MPC, the main modern alternatives are SQP/RTI pipelines, interior-point pipelines, and newer first-order methods such as PANOC.
