#import "@preview/touying:0.5.5": *
#import "@preview/clean-math-presentation:0.1.1": *

#show: clean-math-presentation-theme.with(
  config-info(
    title: [Operator Splitting for Optimal Control],
    authors: (
      (name: "Boyer Timothé"),
      (name: "Hacini Malik"),
      (name: "Lainé Martin"),
      (name: "Mouret Basile"),
    ),
    date: datetime(year: 2026, month: 04, day:22),
  ),
  config-common(
    slide-level: 3,
    //handout: true,
    //show-notes-on-second-screen: right,
  ),
  progress-bar: true,
)

#title-slide()

#include "chapters/intro.typ"

#include "chapters/method.typ"

#include "chapters/implementation.typ"

#include "chapters/demo.typ"

#include "chapters/results.typ"

#include "chapters/conclusion.typ"

#ending-slide()[
  Thank you for your attention !
]

#include "chapters/hyperparams.typ"
