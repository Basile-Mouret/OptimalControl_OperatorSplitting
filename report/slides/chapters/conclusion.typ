#import "@preview/clean-math-presentation:0.1.1": *

= Conclusion <touying:hidden>

#slide(title: "Achievments and future directions")[
	We implemented the operator-splitting method in Julia for finite-horizon
	optimal control with linear dynamics.

	On the benchmark examples, the Julia solver matches the reference C solver
	in iteration counts. Runtime differences depend on the example and on the
	relative cost of the linear-system step versus the proximal step.

	Several extensions would be natural for future work:
	- Study the sensitivity of the hyperparameters ($rho$, $alpha$, and stopping tolerances)
	- Comparison with other optimization methods
	- Test the algo on more examples
	- Convergence-rate results

]