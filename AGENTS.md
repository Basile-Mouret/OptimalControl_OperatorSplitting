# AGENTS.md

This file is a starting point for future agent instructions. It is intentionally generic and should be refined as the project matures.

## Project Purpose

This repository is a Julia research project on operator splitting methods for optimal control.

Initial objective:
- Reimplement in Julia the paper `resources/oper_splt_ctrl.pdf`:
  - Brendan O'Donoghue, Giorgos Stathopoulos, Stephen Boyd,
    "A Splitting Method for Optimal Control," IEEE Transactions on Control Systems Technology, 2013.

## Main Scientific Goal

Agents should understand the paper at a high level before editing core algorithms.

Main ideas from the paper:
- The target problem is a discrete-time, finite-horizon, linear-convex optimal control problem.
- The stage cost is split into:
  - a quadratic part `phi_t(x_t, u_t)`;
  - a convex, possibly nonsmooth or constraint-encoding part `psi_t(x_t, u_t)`.
- The method reformulates the problem in consensus form and applies ADMM / Douglas-Rachford splitting.
- Each iteration alternates between two structured subproblems:
  - a quadratic optimal control step with linear dynamics constraints;
  - a per-time-step proximal step for `psi_t`, often parallelizable and sometimes available in closed form.
- The quadratic step can exploit KKT structure, Riccati-style recursions, or sparse `LDL^T` factorizations.
- The proximal step is where box constraints, nonsmooth penalties, indicator constraints, and similar terms are handled.
- The method targets moderate accuracy very quickly rather than very high precision.
- Warm starts and offline precomputation are important, especially when dynamics and quadratic terms stay fixed.
- In favorable cases, the algorithm can become division-free after precomputation, which is useful for embedded or fixed-point implementations.

## Julia Code Quality

Agents should prefer clear, idiomatic, testable Julia code over quick scripts.

Core rules:
- Write functions, not long top-level scripts.
- Keep numerical kernels type-stable and avoid unnecessary global state.
- Use multiple dispatch and abstract interfaces where it improves clarity.
- Use mutating `!` function names when arguments are modified.
- Keep APIs small and explicit.
- Separate model definition, solver logic, utilities, and experiments.
- Add docstrings for public functions and main types.
- Add tests for every mathematical building block that can be checked independently.
- Do not introduce clever abstractions too early; prefer transparent math-to-code mappings.
- Preserve notation close to the paper when helpful, but rename symbols when code readability would otherwise suffer.

Before making substantial style or refactor changes, agents should consult Julia references with Firecrawl or another web tool.

Recommended documentation URLs:
- Julia style guide:
  - https://docs.julialang.org/en/v1/manual/style-guide/
- Julia performance tips:
  - https://docs.julialang.org/en/v1/manual/performance-tips/
- Julia documentation / docstrings:
  - https://docs.julialang.org/en/v1/manual/documentation/
- Julia package creation and layout:
  - https://pkgdocs.julialang.org/v1/creating-packages/
- Julia testing standard library:
  - https://docs.julialang.org/en/v1/stdlib/Test/
- JuliaFormatter documentation:
  - https://domluna.github.io/JuliaFormatter.jl/stable/
- BlueStyle guide:
  - https://github.com/JuliaDiff/BlueStyle

Practical cleaning guidance:
- Prefer small, composable functions with explicit inputs and outputs.
- Keep allocations under control in iterative solvers.
- Avoid hidden state in global variables.
- Use `struct` for well-defined problem data and solver settings.
- Put research scripts in `scripts/`, reusable code in `src/`, and tests in `test/`.
- If formatting is introduced later, prefer a documented formatter configuration rather than ad hoc manual rewrites.
- Do not mass-reformat the repository unless requested; keep diffs reviewable.

## Project Structure

Current repository snapshot:
- `src/OptimalControl_OperatorSplitting.jl`: main package entry point.
- `scripts/main.jl`: simple executable script.
- `resources/oper_splt_ctrl.pdf`: reference paper.
- `Project.toml` / `Manifest.toml`: Julia environment and dependencies.
- `README.md`, `Setup.md`: high-level notes.

Classical Julia project structure reference for this project:

```text
OptimalControl_OperatorSplitting/
|- Project.toml
|- Manifest.toml
|- README.md
|- AGENTS.md
|- src/
|  |- OptimalControl_OperatorSplitting.jl
|  `- ...
|- test/
|  |- runtests.jl
|  `- ...
|- scripts/
|  |- main.jl
|  `- ...
|- docs/
|  `- ...
|- examples/
|  `- ...
`- resources/
   `- oper_splt_ctrl.pdf
```

Placeholders:
- `src/...`: solver modules and reusable numerical code to be defined later.
- `test/...`: unit and regression tests to be defined later.
- `scripts/...`: research, reproduction, or profiling scripts to be defined later.
- `docs/...`: documentation content to be defined later.
- `examples/...`: example problems or demos to be defined later.

Notes:
- The first priority is solver correctness, not packaging polish.
- As the codebase grows, split `src/` by mathematical responsibility, not by arbitrary file size.
- Put reproducibility scripts and paper experiments outside `src/`.

## Working Style For Agents

When contributing:
- Read the relevant math section of the paper before changing the corresponding solver code.
- Preserve a direct mapping between equations and implementation where practical.
- Add tests alongside new numerical routines.
- Validate dimensions, horizon length, and convexity assumptions when possible.
- Prefer deterministic examples and fixed seeds in benchmarks.
- Record any deviations from the paper clearly in comments, tests, or docs.
