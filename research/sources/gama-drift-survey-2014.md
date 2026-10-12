---
title: 'Gama, Žliobaitė, Bifet, Pechenizkiy, Bouchachia 2014: A Survey on Concept Drift Adaptation'
url: https://eprints.bournemouth.ac.uk/22491/1/ACM%20computing%20surveys.pdf
kind: paper
commit: 
for: [draft-predictor-methods]
looked: 2026-10-12
depth: skimmed (abstract, 2 applications, 3.1 memory and forgetting)
relevance: medium
grade: A/strong
description: ACM Computing Surveys 2014 (accepted version), the canonical concept drift survey: memory, windows, abrupt vs gradual forgetting with exponential age weights, and when recency is not relevance
---
# Gama et al. 2014: A Survey on Concept Drift Adaptation

Why: how to weight older patches when training a win model: hard window vs decay
weights, and their trade-offs.

## Assessment

- Evidence: A. The canonical drift survey (ACM CSUR), thousands of citations; authors
  lead the field (MOA, ADWIN).
- Reasoning: strong. States the trade-off of each memory and forgetting scheme and
  where recency assumptions fail.
- Interests: none known.
- Weigh: trust the taxonomy and trade-offs; no numbers on which wins for a given
  drift rate, so we measure it.

## Findings

- [method] [stats] Window size trade-off: a short window adapts fast but hurts in
  stable periods; a long window is better when stable but reacts slowly. Section 3.1.1 ^f1
  > A short window reflects the current distribution more accurately, thus it can assure fast adaptation in periods with concept changes, but in stable periods too short window worsens the performance of the system.
- [method] [stats] Recency is not relevance when data is noisy or concepts recur; slow
  change longer than the window also defeats windowing. Section 3.1.1 ^f2
  > For instance, when the data is noisy or concepts reoccur, recency of data does not mean relevance.
- [method] [stats] Abrupt forgetting raises reactivity but also the risk of fitting
  noise. Section 3.1.2 ^f3
  > The more abrupt is forgetting, the higher the reactivity, but also the higher risk of capturing noise is.
- [method] [stats] Gradual forgetting keeps all examples and weights them by age, e.g.
  exponential w = exp(-lambda j), lambda = 0 being equal weights. Section 3.1.2 ^f4
  > The latter technique weights examples according to their age using an exponential ageing function wλ (X) = exp(−λj),
- [method] In Netflix-style collaborative filtering, windowing and instance weighting
  were not the best choice; the winners modelled each kind of change separately
  (Koren 2010). Section 2 ^f5
  > As suggested in [Koren 2010] popular windowing and instance weighing approaches for handling concept drift are not the best choice for each kind of changing behaviour
- [method] (inferred) With a label as noisy as a LoL win (f2, f3), a hard last-patch
  window fits noise; exponential decay with lambda tuned on a time-split validation
  set, or explicit time-varying champion terms (f5), are the candidates. ^f6

## Read

- Abstract, 1, 2 (applications incl. Netflix), 3.1 memory and forgetting

## Not read

- 3.2 change detection, 3.3-3.4 learning and loss estimation, 4 evaluation
