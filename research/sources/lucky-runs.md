---
title: Separating Real Improvements from Lucky Runs in Autonomous ML Research
url: https://neurips.cc/virtual/2026/157611
kind: paper
commit:
for: [agent-ml-practice]
looked: 2026-10-13
depth: skimmed (abstract only)
relevance: high
grade: C/fair
description: NeurIPS 2026 workshop poster (Grover): in an autoresearch-style nanoGPT setup, best-of-32 selection alone fakes a 2.7x-threshold gain; replication of an agent's candidate bank with sealed seeds
---
# Separating Real Improvements from Lucky Runs in Autonomous ML Research

Why: how many of an autoresearch-style agent's kept changes survive independent seeds.

## Assessment

- Evidence: C. Workshop poster, single author, one nanoGPT setup; 749 training runs, 60
  seeds for the null distribution, preregistered threshold. Only the abstract read.
- Reasoning: fair on the face of the abstract: null controls, sealed evaluation seeds,
  preregistration.
- Interests: none known.
- Weigh: the selection-bias number is the useful part; the replication counts are from a
  24-candidate bank built partly by hand (null controls, benchmark interventions).

## Findings

- [lab] Selection alone fakes gains: picking the best of 32 runs of the same program
  gives an expected val_bpb "improvement" of 0.00544, 2.7 times the preregistered
  meaningful threshold of 0.002. ^f1
  > Selecting the best of 32 runs produces an expected apparent improvement of 0.00544 validation bits-per-byte (val_bpb), or 2.7 times our preregistered meaningful-effect threshold delta = 0.002, a gain produced entirely by selection.
- [lab] Replication with sealed seeds the agent never saw: of 15 non-null candidates, 8
  replicated, 3 failed, 4 stayed inconclusive. ^f2
  > Of the remaining 15 candidates, eight independently replicate as meaningful improvements, three fail replication, and four remain inconclusive.
- [lab] Large effects (about 0.014 val_bpb, 7x threshold) are confirmed easily and the
  preregistered search and confirmation policies made no false declarations; effects
  near the threshold stayed unresolved after 24-33 sealed evaluations. ^f3
  > The harder cases are the smaller improvements near delta, several of which remain unresolved even after 24-33 sealed evaluations.
- [lab] (inferred) Karpathy's "all ~20 changes were real" fits this: his kept changes
  were large relative to noise. Meiolol's model changes sit near noise, the regime where
  this paper needs dozens of seeds per candidate. ^f4

## Read

- NeurIPS virtual page abstract.

## Not read

- Full paper (OpenReview x3lY2QO0Xe): the search and confirmation policies themselves,
  seeds per stage, cost.
