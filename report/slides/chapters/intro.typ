#import "@preview/clean-math-presentation:0.1.1": *

= Introduction <touying:hidden>

#slide(title: "What's optimal control?")[
     #grid(
  columns: (auto, auto),
  [
	Optimal control is about choosing *inputs* for a *dynamical system* so that it behaves as desired while *minimizing a cost*.

	In many applications, the state evolves over time and each decision affects both the immediate cost and the future trajectory. This temporal coupling is what makes the problem both useful and difficult.
  ],
    align(end + horizon)[
    #image("../figures/fusee.jpg", width: 95%)
  ]
  
  )


    #grid(
  columns: (auto,auto),
  [
    Goal: keep the indoor temperature close to 20°C over time. Here, the *state* is the room temperature $T$, and the *control* is the power $P$ sent to the radiator.

    $
      T_(t+1) = f(T_t, P_t)
    $

    - We minimize thermal discomfort and electricity usage.
    - We respect the limits: radiator power cannot go below 0 W or exceed a maximum value.
    
    Optimal control finds the best heating sequence to balance comfort and cost under these limits.
  ],
  align(end + horizon)[
    #image("../figures/thermostat.jpg", width: 90%, )
  ]
  )
]

#slide(title: "Why the splitting method?")[
  #grid(
    columns: (auto, auto),
  [
	We used the method proposed by O'Donoghue, Stathopoulos, and Boyd because it
	is designed to exploit this problem structure directly.

	Alternative approaches such as CVX or fast MPC can also be used on related optimal-control problems, but OSC (operator splitting for control) is especially well suited to our setting.
  ],
    image("../figures/convex_opt.jpg")
  )
]
