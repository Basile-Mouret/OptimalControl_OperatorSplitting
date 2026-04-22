#import "@preview/clean-math-presentation:0.1.1": *

= Conclusion <touying:hidden>

#slide(title: "Recap and Future work")[
	We implemented the operator-splitting method in Julia for finite-horizon
	optimal control with linear dynamics.

	On the benchmark examples, the Julia solver matches the reference C solver
	in iteration counts. Runtime differences depend on the example and on the
	relative cost of the linear-system step versus the proximal step.


        Possible extensions : 
  - Using a native Julia linear solver
	- Test on more examples
	- Convergence-rate results

]
