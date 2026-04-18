#import "@preview/hei-synd-report:0.1.1": *
#import "metadata.typ": *
#import "extra.typ": *
//#show:make-glossary
//#register-glossary(entry-list)

//-------------------------------------
// Template config
//
#show: report.with(
  option: option,
  doc: doc,
  date: date,
  tableof: tableof,
)

//-------------------------------------
// Content
//
#counter(page).update(1)

= Introduction

#include "chapters/introduction.typ" //Martin

= Method 

#include "chapters/method.typ" // Malik

= Implementation

#include "chapters/implementation.typ" // Basile

#pagebreak()
= Results
#include "chapters/results.typ" // Tim, rajoue plot solveur quelconque, hyper parametre 

#pagebreak()
= Conclusion

#include "chapters/conclusion.typ" // Martin

#bibliography("references.bib", style: "ieee", title: [References])
