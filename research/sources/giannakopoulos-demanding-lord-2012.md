---
title: 'Giannakopoulos and Palpanas 2012: Revisiting the Effect of History on Learning Performance, the Problem of the Demanding Lord (KAIS)'
url: https://helios2.mi.parisdescartes.fr/~themisp/publications/kais12-demandinglord.pdf
kind: paper
commit: 
for: [frontier-dynamics]
looked: 2026-10-21
depth: docs (abstract, sections 1, 4 opening, 7)
relevance: low
grade: C/fair
description: Knowledge and Information Systems 2012; analytic model of average accuracy as a function of memory window size relative to the concept shift period, via the signal-to-noise of the training window; synthetic and four real datasets
---
# Giannakopoulos and Palpanas 2012: Revisiting the Effect of History on Learning Performance, the Problem of the Demanding Lord

Why: is there a principled way to ask whether our plateau is a drift limit, i.e. how
memory length trades signal for staleness?

## Assessment

- Evidence: C. One group's analytic model with experiments on synthetic and four real
  datasets; assumes whole-concept shifts.
- Reasoning: fair. Clear framing; the assumptions (periodic, total shifts) don't fit a
  patch, which changes a few champions.
- Interests: none known.
- Weigh: use the framing (memory / shift-period ratio, signal-to-noise of the window),
  not the formulas.

## Findings

- [method/dynamics] Framing: a learner's average accuracy depends on the signal-to-noise
  of its training window; with concept shifts, a window longer than the shift period
  mixes old concepts in as noise. Abstract, section 4 ^f1
  > Using a signal-to-noise approach to sketch learning ability of underlying machine learning algorithms, we estimate the average performance of a learning system regardless of its underlying algorithm
- [method/dynamics] With memory much longer than the shift period, old concepts dominate
  and average accuracy falls toward the learner's minimum ("infinite-memory servant").
  Section 4 ^f2
  > the average performance provided by Equation 16 will indefinitely decrease to asymptotically reach the minimum value, as ρ → ∞ (Infinite-memory servant).
- [method/dynamics] The useful quantity is the ratio of memory window to shift period;
  the estimate is good when the window is not longer than the average shift period.
  Section 7 ^f3
  > the system still provides a good estimate of performance as a function of the “memory window”-to-“shift period” ratio
- [method/dynamics] (inferred) For LoL the shift is partial (a patch moves a few
  champions by a point or two; most champion strengths carry over), so the old games'
  "noise" share is small and long memory wins until many patches have passed; the
  test is empirical: at equal game counts, compare a window of the newest W days with
  a sample spread over all days. ^f4
- [method/dynamics] Checked, not there: no partial or local drift, no pooled model with
  per-period offsets as an alternative to windowing. ^f5

## Read

- Abstract, introduction, section 4 opening (CTF), section 7.

## Not read

- Sections 5-6 experiments in detail.
