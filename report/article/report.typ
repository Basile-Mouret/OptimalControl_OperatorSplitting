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
= Introduction

#include "chapters/introduction.typ" //Martin


= Method // Malik

#include "chapters/method.typ"

= Implementation

#include "chapters/implementation.typ" // Basile

= Results

#include "chapters/results.typ" // Tim



= Conclusion

#include "chapters/conclusion.typ" // Martin
