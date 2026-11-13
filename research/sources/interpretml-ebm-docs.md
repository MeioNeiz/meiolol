---
title: 'InterpretML docs: Explainable Boosting Machine'
url: https://interpret.ml/docs/ebm.html
kind: docs
commit: 
for: [frontier-interactions]
looked: 2026-11-13
depth: docs (whole page)
relevance: medium
grade: A/fair
description: Official overview page for EBM (InterpretML); cyclic one-feature-at-a-time boosting at a low learning rate plus automatically detected pair terms; says nothing on categoricals, purification or data size
---
# InterpretML docs: Explainable Boosting Machine

Why: what the standard GA2M tool says it does, before reading the code
([[interpretml-ebm-code]]), as a Python cross-check candidate for our shrunk
main + pair-cell logistic model.

## Assessment

- Evidence: A. Official documentation of the reference GA2M implementation (Microsoft
  Research origin, repo since 2019, 6,979 stars; see [[interpretml-ebm-code]]).
- Reasoning: fair. An overview: states the model form and the training idea, cites the
  papers for details, no limits or failure cases.
- Interests: the project's own page; "often as accurate as state-of-the-art blackbox
  models" is a claim here, with one Adult example (AUC 0.931).
- Weigh: trust the model form and training outline; every detail that matters for
  170-level nominal seats is absent here and has to come from the code.

## Findings

- [method/interpret] The docs say EBM boosts one feature at a time in round-robin order
  at a very low learning rate, so that feature order does not matter. How it Works ^f1
  > The boosting procedure is carefully restricted to train on one feature at a time in round-robin fashion using a very low learning rate so that feature order does not matter.
- [method/interpret] The docs say pair terms are detected automatically and that EBM is
  an implementation of GA2M (Lou et al. 2013, [[lou-ga2m-2013]]), in C++ and Python,
  parallel through joblib. How it Works ^f2
  > EBM is a fast implementation of the GA2M algorithm
  > The implementation is parallelizable, and takes advantage of joblib to provide multi-core and multi-machine parallelization.
- [method/interpret] The docs say each term is a lookup table; a prediction adds the
  looked-up contributions and applies the link. How it Works ^f3
  > These term contributions are simply added up, and passed through the link function g to compute the final prediction.
- [method/interpret] (claim) The docs say training costs more than similar methods, the
  price of keeping terms additive. How it Works ^f4
  > To keep the individual terms additive, EBM pays an additional training cost, making it somewhat slower than similar methods.
- [method/interpret] Checked, not there: nothing on nominal or high-cardinality
  categoricals, on purification of pair terms, on row or memory limits, or on noisy
  labels. ^f5

## Read

- Whole page (Summary, How it Works, Code Example, Bibliography).

## Not read

- The linked video and the 2012 and 2015 papers.
- The API page (ExplainableBoostingClassifier.html): read instead as the class
  docstring in the clone, [[interpretml-ebm-code]].
