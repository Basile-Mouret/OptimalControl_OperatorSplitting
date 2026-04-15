# Julia Survey for Optimal Control, MPC, and Operator Splitting

Survey date: 2026-03-14

This note summarizes the current Julia ecosystem relevant to this repository, whose main scientific reference is `resources/oper_splt_ctrl.pdf` (O'Donoghue, Stathopoulos, Boyd, 2013, *A Splitting Method for Optimal Control*).

The focus here is:

- discrete-time optimal control and MPC;
- operator splitting, ADMM, and proximal methods;
- trajectory optimization and numerical optimal control;
- performance questions, especially GPU suitability.

This is a web-and-documentation survey, not an installation benchmark. The conclusions are based on public documentation, repository metadata, and package readmes.

## Executive Summary

- Julia is a viable language for this project.
- The ecosystem is real and useful, but it does **not** appear to contain a maintained Julia package that directly implements the exact O'Donoghue-Stathopoulos-Boyd splitting algorithm for finite-horizon linear-convex optimal control.
- The strongest nearby open-source packages are:
  - `OptimalControl.jl` for mathematical optimal control and continuous-time OCPs;
  - `ModelPredictiveControl.jl` for open-source MPC in Julia;
  - `TrajectoryOptimization.jl` + `Altro.jl` for fast robotics-style trajectory optimization;
  - `OSQP.jl`, `COSMO.jl`, `ProximalOperators.jl`, and `ProximalAlgorithms.jl` for solver and splitting infrastructure.
- For this repository, the best strategy is still to implement the paper's solver core yourself and use existing Julia packages for:
  - system modeling and simulation;
  - Riccati/LQR and matrix-equation utilities;
  - baselines and comparisons;
  - proximal / operator-splitting primitives where convenient.
- Julia is also a good language for GPU programming. In this problem family, the most GPU-friendly parts are the stagewise proximal step and batched/scenario-parallel workloads. A single Riccati-style quadratic step for one modest horizon is much less obviously GPU-favorable.

## Status Labels Used Below

- **Mature / active**: recent activity, docs, tests, and clear user-facing scope.
- **Active / research-grade**: serious ongoing development, but still closer to research software than commodity tooling.
- **Niche / early**: useful but narrow, prototype-like, or lightly adopted.
- **Legacy / aging**: interesting historically, but signs of older APIs or stale maintenance.

## Main Conclusion for This Project

I did **not** find a maintained Julia reimplementation of the 2013 paper's algorithm itself.

So the central question is not "which existing Julia package already solves my exact problem?" but rather:

- which packages provide the best surrounding infrastructure, and
- which packages are good baselines to compare against.

## Ecosystem Map

### 1. Mathematical Optimal Control and OCP Solvers

These packages are closest to the mathematical optimal-control side of the project.

| Package | Scope | Snapshot | Status | Notes |
| --- | --- | --- | --- | --- |
| [`control-toolbox/OptimalControl.jl`](https://github.com/control-toolbox/OptimalControl.jl) | Model and solve ODE optimal control problems; direct and indirect methods; CPU/GPU | 123 stars, pushed 2026-03-14 | Active / research-grade | Strongest open Julia package for mathematical optimal control; not specialized to the 2013 splitting paper |
| [`control-toolbox/CTDirect.jl`](https://github.com/control-toolbox/CTDirect.jl) | Direct transcription subpackage | 12 stars, pushed 2026-03-13 | Active / research-grade | Useful if you want direct-method baselines inside the control-toolbox ecosystem |
| [`control-toolbox/CTFlows.jl`](https://github.com/control-toolbox/CTFlows.jl) | Classical and Hamiltonian flows | 2 stars, pushed 2026-03-09 | Active / niche | More useful for geometrical / Hamiltonian analysis than for your exact discrete-time convex setting |

Assessment:

- `OptimalControl.jl` is the strongest research-grade open-source Julia package in this domain.
- It is a very good reference ecosystem, but not the natural substrate for implementing the paper's discrete-time ADMM-style solver.
- It is more continuous-time ODE / direct-transcription / indirect-method oriented than discrete-time convex splitting oriented.

### 2. MPC and Control Engineering Packages

These are the most relevant packages if the project is viewed from the MPC / constrained optimal-control engineering side.

| Package | Scope | Snapshot | Status | Notes |
| --- | --- | --- | --- | --- |
| [`JuliaControl/ModelPredictiveControl.jl`](https://github.com/JuliaControl/ModelPredictiveControl.jl) | Open-source MPC and MHE for linear and nonlinear models | 115 stars, pushed 2026-03-13 | Mature / active | Probably the healthiest open-source Julia MPC package right now |
| [`darnstrom/LinearMPC.jl`](https://github.com/darnstrom/LinearMPC.jl) | Linear MPC with embedded C code generation | 20 stars, pushed 2026-02-16 | Active / narrow | Attractive for embedded linear MPC workflows; much narrower in scope |
| [`DyadControlSystems` docs](https://help.juliahub.com/dyad/DyadControlSystems.jl/stable/) | MPC, optimal control, robust control, ModelingToolkit integration | public docs available | Product / platform | Broad and capable, but not a standard open-source package dependency in the same sense as the repos above |

Assessment:

- `ModelPredictiveControl.jl` is the closest open package to the class of problems in this repository: finite-horizon constrained control.
- Its feature set is broad: linear and nonlinear MPC, state estimation, MHE, direct shooting, collocation, adaptive linearization, and integration with JuMP.
- It is still an engineering MPC toolkit, not a specialized first-order structure-exploiting solver package for the specific operator-splitting method of the 2013 paper.
- `LinearMPC.jl` is especially interesting if you later care about embeddable linear MPC implementations and code generation.

### 3. Trajectory Optimization and DDP / iLQR Packages

These packages are strongest in robotics-style nonlinear trajectory optimization.

| Package | Scope | Snapshot | Status | Notes |
| --- | --- | --- | --- | --- |
| [`RoboticExplorationLab/TrajectoryOptimization.jl`](https://github.com/RoboticExplorationLab/TrajectoryOptimization.jl) | Fast trajectory-optimization problem-definition layer | 393 stars, pushed 2025-03-27 | Mature / active | Very strong problem-definition and evaluation layer |
| [`RoboticExplorationLab/Altro.jl`](https://github.com/RoboticExplorationLab/Altro.jl) | ALTRO solver: augmented Lagrangian + iLQR | 189 stars, pushed 2025-03-06 | Mature / active | Fast constrained trajectory optimization; important Julia success story |
| [`mingu6/FilterDDP.jl`](https://github.com/mingu6/FilterDDP.jl) | Constrained DDP with filter line search | 5 stars, pushed 2026-02-21 | Niche / early | Promising research package, still early |
| [`baggepinnen/DifferentialDynamicProgramming.jl`](https://github.com/baggepinnen/DifferentialDynamicProgramming.jl) | DDP / iLQG | 77 stars, pushed 2021-05-13 | Legacy / aging | Historically useful, but stale |
| [`thowell/DirectTrajectoryOptimization.jl`](https://github.com/thowell/DirectTrajectoryOptimization.jl) | Direct trajectory optimization | 29 stars, pushed 2022-06-12 | Legacy / aging | Interesting but likely not central for new work |

Assessment:

- This is one of Julia's strongest optimization-for-control niches.
- `TrajectoryOptimization.jl` and `Altro.jl` are mature and performant, but they target nonlinear trajectory optimization and iLQR-like methods, not linear-convex ADMM splitting.
- They are valuable as performance/style references, but not as direct implementations of your target algorithm.

### 4. General Dynamic / Infinite-Dimensional Optimization Modeling

| Package | Scope | Snapshot | Status | Notes |
| --- | --- | --- | --- | --- |
| [`infiniteopt/InfiniteOpt.jl`](https://github.com/infiniteopt/InfiniteOpt.jl) | JuMP extension for infinite-dimensional, dynamic, stochastic optimization | 313 stars, pushed 2026-01-14 | Mature / active | Excellent general modeling layer; broader than standard OCP |
| [`JuliaMPC/NLOptControl.jl`](https://github.com/JuliaMPC/NLOptControl.jl) | Nonlinear optimal control via direct collocation | 115 stars, pushed 2025-03-22 | Legacy / aging | Repo still moves, but README and install instructions are clearly from older Julia eras |
| [`JuDO-dev/Interesso.jl`](https://github.com/JuDO-dev/Interesso.jl) | Trajectory optimization solver | 3 stars, pushed 2025-12-13 | Niche / early | Interesting but small and not yet central |
| [`JuliaStochOpt/StochDynamicProgramming.jl`](https://github.com/JuliaStochOpt/StochDynamicProgramming.jl) | Discrete-time stochastic dynamic programming | 64 stars, pushed 2020-04-07 | Legacy / aging | Relevant if stochastic dynamic programming becomes important later |

Assessment:

- `InfiniteOpt.jl` is impressive and useful if the project later moves into more general dynamic or stochastic formulations.
- For the present project, it is probably too general as a starting point for the core solver.
- `NLOptControl.jl` looks historically important, but I would treat it cautiously because the public interface and docs show older Julia ecosystem assumptions.

### 5. Proximal / ADMM / Operator-Splitting Packages

These are the most relevant generic optimization packages for the operator-splitting side of the paper.

| Package | Scope | Snapshot | Status | Notes |
| --- | --- | --- | --- | --- |
| [`JuliaFirstOrder/ProximalOperators.jl`](https://github.com/JuliaFirstOrder/ProximalOperators.jl) | Library of proximal operators | 140 stars, pushed 2026-01-15 | Mature / active | Very relevant for stagewise prox steps |
| [`JuliaFirstOrder/ProximalAlgorithms.jl`](https://github.com/JuliaFirstOrder/ProximalAlgorithms.jl) | Generic proximal / splitting algorithms | 140 stars, pushed 2025-05-24 | Mature / active | Includes Douglas-Rachford and other splitting methods |
| [`JuliaFirstOrder/SeparableOptimization.jl`](https://github.com/JuliaFirstOrder/SeparableOptimization.jl) | ADMM for linearly constrained separable optimization | 31 stars, pushed 2021-07-19 | Niche / useful | Conceptually close to your paper, but not control-specific and not very active |
| [`osqp/OSQP.jl`](https://github.com/osqp/OSQP.jl) | Julia wrapper for OSQP | 72 stars, pushed 2025-03-07 | Mature / active | Important baseline because OSQP itself is operator splitting for QPs |
| [`oxfordcontrol/COSMO.jl`](https://github.com/oxfordcontrol/COSMO.jl) | Conic operator splitting solver in Julia | 309 stars, pushed 2025-08-02 | Mature / active | Strong convex optimization baseline |
| [`exanauts/ExaAdmm.jl`](https://github.com/exanauts/ExaAdmm.jl) | Multi-GPU ADMM implementation | 23 stars, pushed 2026-03-08 | Active / domain-specific | Shows Julia can support serious ADMM-on-GPU work |
| [`kul-optec/spock.jl`](https://github.com/kul-optec/spock.jl) | Proximal solver for multistage risk-averse optimal control | 3 stars, pushed 2023-04-03 | Niche / research | Closest in spirit to your project, but specialized and lightly maintained |

Assessment:

- This is the best source of building blocks for your paper's algorithm.
- `ProximalOperators.jl` and `ProximalAlgorithms.jl` are especially useful for experimentation and for validating proximal-step logic.
- `OSQP.jl` and `COSMO.jl` are highly relevant baselines when comparing a custom structure-exploiting solver against generic convex/QP formulations.
- `SeparableOptimization.jl` is conceptually interesting because it targets linearly constrained separable problems with ADMM, but it is not a drop-in optimal-control package.
- `spock.jl` is especially worth noting because it is a Julia proximal optimal-control solver, but it is focused on risk-averse multistage problems rather than the deterministic linear-convex setting of this repository.

### 6. Control and Linear-Algebra Infrastructure

These are not full optimal-control packages, but they are important support libraries.

| Package | Scope | Snapshot | Status | Notes |
| --- | --- | --- | --- | --- |
| [`JuliaControl/ControlSystems.jl`](https://github.com/JuliaControl/ControlSystems.jl) | Core control-systems toolbox | 575 stars, pushed 2026-03-13 | Mature / active | Essential LTI/control infrastructure |
| [`JuliaControl/RobustAndOptimalControl.jl`](https://github.com/JuliaControl/RobustAndOptimalControl.jl) | Robust and optimal linear control | 65 stars, pushed 2026-01-29 | Mature / active | Useful for LQG, robust design, and linear-control analysis |
| [`andreasvarga/MatrixEquations.jl`](https://github.com/andreasvarga/MatrixEquations.jl) | Lyapunov / Sylvester / Riccati solvers | 92 stars, pushed 2025-10-14 | Mature / active | Very relevant for Riccati and matrix-equation baselines |
| [`oxfordcontrol/SwitchTimeOpt.jl`](https://github.com/oxfordcontrol/SwitchTimeOpt.jl) | Switching-time optimization | 16 stars, pushed 2024-04-01 | Niche / aging | Useful only if switched-system extensions become important |

Assessment:

- `ControlSystems.jl` and `MatrixEquations.jl` are especially relevant for your project.
- Even if the main solver is custom, these packages can provide trusted support for:
  - state-space model handling;
  - LQR and Riccati sanity checks;
  - system analysis and baseline controller construction.

## Packages Closest to the 2013 Paper's Niche

For the exact flavor of this repository, the most relevant packages are:

1. [`ModelPredictiveControl.jl`](https://github.com/JuliaControl/ModelPredictiveControl.jl)
   - Closest engineering-side package to finite-horizon constrained control.
   - Good for benchmarking closed-loop behavior and API ideas.

2. [`LinearMPC.jl`](https://github.com/darnstrom/LinearMPC.jl)
   - Closest smaller open package to linear MPC and embedded deployment.

3. [`ProximalOperators.jl`](https://github.com/JuliaFirstOrder/ProximalOperators.jl) and [`ProximalAlgorithms.jl`](https://github.com/JuliaFirstOrder/ProximalAlgorithms.jl)
   - Most relevant generic Julia packages for the proximal / splitting side.

4. [`OSQP.jl`](https://github.com/osqp/OSQP.jl) and [`COSMO.jl`](https://github.com/oxfordcontrol/COSMO.jl)
   - Best generic solver baselines when the problem is written as a QP or conic problem.

5. [`spock.jl`](https://github.com/kul-optec/spock.jl)
   - The closest Julia research code in spirit: a proximal optimal-control solver.
   - But it is specialized to multistage risk-averse problems and appears lightly maintained.

6. [`OptimalControl.jl`](https://github.com/control-toolbox/OptimalControl.jl)
   - The best mathematical optimal-control ecosystem in Julia, but not the most direct fit for this discrete-time convex splitting method.

## What Seems Missing in Julia

The following gap is the most relevant one for this repository:

- a maintained, open Julia package specifically for **finite-horizon linear-convex optimal control solved by consensus splitting / ADMM with a structured quadratic dynamics step and separable per-stage proximal updates**.

This gap is exactly why a custom implementation in this repository still makes sense.

## Performance and GPU Parallelization

## Is Julia good for GPU parallelization for these problems?

Yes, with an important qualification:

- Julia is good for GPU programming in general.
- Julia is good for some optimal-control workloads on GPU.
- But whether **your specific operator-splitting optimal-control method** benefits strongly from GPU depends on which part of the algorithm dominates runtime.

### GPU State of the Julia Ecosystem

Julia has first-class GPU support through:

- [`CUDA.jl`](https://cuda.juliagpu.org/stable/) for NVIDIA GPUs;
- [`AMDGPU.jl`](https://amdgpu.juliagpu.org/stable/) for AMD GPUs;
- [`oneAPI.jl`](https://github.com/JuliaGPU/oneAPI.jl) for Intel GPUs;
- [`Metal.jl`](https://github.com/JuliaGPU/Metal.jl) for Apple GPUs;
- [`KernelAbstractions.jl`](https://juliagpu.github.io/KernelAbstractions.jl/stable/) for vendor-agnostic kernels.

According to the ENCCS Julia-for-HPC material:

- `CUDA.jl` is the most mature backend;
- `AMDGPU.jl` is usable and increasingly serious;
- `oneAPI.jl` and `Metal.jl` exist but are less mature.

### Evidence Inside the Julia Control / Optimization Ecosystem

- `OptimalControl.jl` explicitly documents GPU solving using [`ExaModels.jl`](https://github.com/exanauts/ExaModels.jl) + [`MadNLPGPU.jl`](https://github.com/MadNLP/MadNLP.jl) + `CUDA.jl` for direct-transcribed optimal-control problems.
- `ExaAdmm.jl` is a Julia implementation of ADMM on multiple GPUs in another application area, showing that Julia is capable of serious GPU-first ADMM implementations.
- `ExaModels.jl` and `MadNLP.jl` provide GPU-enabled nonlinear-programming infrastructure in Julia.

So the answer is not merely theoretical: there is already working Julia software for both:

- GPU optimal-control workflows;
- GPU-accelerated ADMM / optimization workflows.

### Which Parts of Your Target Algorithm Are GPU-Friendly?

For a solver based on the 2013 paper, the main pieces are:

1. a quadratic optimal-control step with linear dynamics constraints;
2. a per-time-step proximal step for the nonsmooth / constraint part;
3. dual-variable and residual updates.

Their GPU suitability is not the same.

#### Very GPU-friendly parts

- **Stagewise proximal step**
  - This is the most obviously parallel part.
  - If each time step has its own prox evaluation, the horizon can be processed stagewise in parallel.
  - If you solve many similar problems or many scenarios in batch, this becomes even more attractive.

- **Residual and multiplier updates**
  - These are often vectorized / elementwise and map naturally to GPU kernels.

- **Batching across many problem instances**
  - If you solve many MPC instances, many scenarios, many initial conditions, or perform large hyperparameter sweeps, GPU payoff becomes much more plausible.

#### Less obviously GPU-friendly parts

- **Single Riccati-style quadratic step for one problem**
  - A backward Riccati sweep and forward rollout have serial structure along the time horizon.
  - This can limit GPU speedups for a single modest-size control problem.

- **Small to medium horizons with modest state dimension**
  - GPU launch overhead and transfer overhead can outweigh gains.
  - A carefully optimized CPU implementation may be better here.

- **Branch-heavy custom prox logic**
  - If the prox operator has many conditionals and irregular data access, GPU efficiency can suffer.

### Practical Performance Guidance for This Repository

For this project, the strongest performance path is likely:

1. Build a clean CPU reference implementation first.
2. Keep the solver modular so that the following can be swapped independently:
   - quadratic-step backend;
   - proximal-step backend;
   - linear algebra storage/layout;
   - residual-update kernels.
3. Benchmark where the time actually goes.
4. If the proximal step dominates, GPU acceleration is very promising.
5. If the structured quadratic step dominates and you solve one problem at a time, CPU optimization may be better than GPU.

### GPU Suitability by Use Case

| Use case | Julia on GPU? | Expected payoff |
| --- | --- | --- |
| Single small/medium deterministic horizon problem | Yes | Often limited |
| Large batched MPC rollouts or many scenarios | Yes | Potentially strong |
| Stagewise proximal maps across horizon | Yes | Strong candidate |
| Generic direct-transcribed NLP solve on NVIDIA GPU | Yes | Already supported in parts of ecosystem |
| One-off Riccati recursion for modest dimensions | Yes in principle | Often not the first thing to accelerate |

### Important Implementation Caveats

- Keep data on the GPU once moved there; repeated CPU-GPU transfers kill performance.
- Prefer in-place, allocation-free kernels.
- Use type-stable code and avoid scalar indexing on GPU arrays.
- Benchmark `Float32` vs `Float64`; GPUs often strongly prefer `Float32`, but control / QP numerics may require `Float64`.
- If GPU support is important, NVIDIA currently has the best-supported Julia stack.

### Best Reading Trail for Performance / GPU Work

- [`CUDA.jl` docs](https://cuda.juliagpu.org/stable/)
- [`KernelAbstractions.jl` docs](https://juliagpu.github.io/KernelAbstractions.jl/stable/)
- [`OptimalControl.jl` GPU manual](https://control-toolbox.org/OptimalControl.jl/stable/manual-solve-gpu.html)
- [`OptimalControl.jl` GPU note](https://control-toolbox.org/OptimalControl.jl/stable/jlesc17.html)
- [`ExaModels.jl`](https://github.com/exanauts/ExaModels.jl)
- [`MadNLP.jl`](https://github.com/MadNLP/MadNLP.jl)
- [`ExaAdmm.jl`](https://github.com/exanauts/ExaAdmm.jl)

## Recommendation for This Repository

For the present project, the most sensible Julia strategy is:

### Core solver

- Implement the 2013 paper's algorithm yourself.
- Keep the code small, explicit, and close to the mathematics.
- Treat the repository as a research codebase, not as a wrapper around a general package.

### Use the ecosystem around the solver

- **For models and linear systems**: `ControlSystems.jl`
- **For Riccati / Lyapunov / matrix equations**: `MatrixEquations.jl`
- **For linear-control baselines**: `RobustAndOptimalControl.jl`
- **For MPC baselines**: `ModelPredictiveControl.jl`, `LinearMPC.jl`
- **For convex/QP baselines**: `OSQP.jl`, `COSMO.jl`
- **For proximal experimentation**: `ProximalOperators.jl`, `ProximalAlgorithms.jl`

### Suggested development order

1. Implement the deterministic CPU solver from the paper.
2. Validate against small hand-checkable examples and generic QP baselines.
3. Add warm starts, residual checks, and penalty-parameter tuning.
4. Benchmark against `OSQP.jl` / JuMP formulations.
5. Only then consider GPU acceleration of the proximal step or batched workflows.

## Short Dependency Shortlist

If the goal is to keep dependencies small and useful, the best shortlist is probably:

- [`ControlSystems.jl`](https://github.com/JuliaControl/ControlSystems.jl)
- [`MatrixEquations.jl`](https://github.com/andreasvarga/MatrixEquations.jl)
- [`OSQP.jl`](https://github.com/osqp/OSQP.jl)
- [`COSMO.jl`](https://github.com/oxfordcontrol/COSMO.jl)
- [`ProximalOperators.jl`](https://github.com/JuliaFirstOrder/ProximalOperators.jl)

Optional, depending on direction:

- [`ModelPredictiveControl.jl`](https://github.com/JuliaControl/ModelPredictiveControl.jl)
- [`LinearMPC.jl`](https://github.com/darnstrom/LinearMPC.jl)
- [`OptimalControl.jl`](https://github.com/control-toolbox/OptimalControl.jl)

## Final Assessment

Julia is strong enough for this project.

Its main strengths for this repository are:

- expressive scientific code close to the mathematics;
- good linear algebra and control infrastructure;
- open-source MPC and optimal-control ecosystems to learn from;
- real GPU support if the solver structure eventually benefits from it.

Its main limitation for this project is not the language, but the absence of an already-existing open Julia package that directly implements the exact operator-splitting method in the paper. That gap is precisely where this repository can contribute something genuinely useful.
