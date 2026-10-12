---
title: 'Build, Compute, Critique, Repeat: Data Analysis with Latent Variable Models (Blei, 2014)'
url: https://web.archive.org/web/2020/http://www.cs.columbia.edu/~blei/papers/Blei2014b.pdf
kind: paper
commit: 
for: [smart-experiment-search]
looked: 2026-10-12
depth: skimmed (abstract, section 1 Box's loop, section 5 model criticism, section 6)
relevance: medium
grade: A/fair
description: Annual Review of Statistics review (2014) framing model building as Box's loop (build, compute, critique, revise) and arguing for model criticism via held-out predictive scores and posterior predictive checks
---
# Build, Compute, Critique, Repeat: Data Analysis with Latent Variable Models (Blei, 2014)

Why: does diagnosing where a model is wrong give a principled way to choose the next
model change, rather than trying many changes blind?

## Assessment

- Evidence: A. Canonical review in Annual Review of Statistics and Its Application by a
  recognised expert (LDA, variational inference); the loop framing is widely cited.
- Reasoning: fair. Clear on the loop and on criticism versus selection, but the
  criticism section is a survey with examples, not an evaluated procedure; no evidence
  that criticism-led revision beats undirected search.
- Interests: none known (academic review).
- Weigh: trust the framing and the distinction between criticism and selection. The
  examples are latent variable models; the technique (task-specific discrepancies,
  looking for patterns in per-item held-out scores) ports to our per-game log loss.
  Only official copy found was a web.archive.org snapshot of the author's corrected
  version.

## Findings

- [method] [lab] Box's loop: formulate a simple model, compute with it, test it against
  the data to find where it succeeds and fails, revise according to the criticism and
  repeat. `section 1` ^f1
  > Finally, use the posterior to test the model against the data, identifying the important ways that it succeeds and fails. If satisfied, use the model to solve the problem; if not satisfied, revise the model according to the results of the criticism and repeat the cycle.
- [method] Model criticism differs from model selection: it can be done with no
  alternative in mind, and its purpose is to show where a model falls short. `section 5`
  ^f2
  > First, we can criticize a model either with or without an alternative in mind.
  > Criticism techniques seek to show how a model falls short and point to where we should make it more complex.
- [method] [stats] Per-item held-out predictive scores can be inspected like residuals:
  look for patterns in poor predictions to find where the model fails. `5.1` ^f3
  > the individual scores in Equation 17 can be examined in the same way that we examine residuals—practitioners can look for patterns in poor predictions to identify where a model succeeds and fails.
- [method] [stats] Posterior predictive checks use a discrepancy chosen for what
  matters to the task, so a simplified model is judged only on the aspects we care
  about. `5.2` ^f4
  > PPCs cleanly separate what we care about modeling from what we easily can model.
  > we define a discrepancy T .X / to be a function of the data that matters to us
- [method] Discrepancies are adaptable: a median, conditional probabilities as the
  model will be used, or weighted towards the observations that matter; several can be
  checked reusing computation. `5.2` ^f5
  > the log score discrepancy can be the median of the log probabilities to account for outliers, a set of conditional probabilities if that is how the model will be used, or weighted towards the kinds of observations that are important to model well in the application at hand.
- [method] Worked examples of the loop: Belin and Rubin used checks to build four
  increasingly complex models on one data set before settling on one; PPCs can also
  suggest when to stop expanding. `5.2` ^f6
  > Belin and Rubin (1995) and Gelman et al. (2005) provide two good examples of how PPCs can iteratively point to new models and help suggest when to stop expanding.
- [method] Netflix prize winners followed the loop: simple matrix models first, then
  embellishments (time, latent popularity) prompted by criticism. `3.3` ^f7
  > they fit simple matrix models first and then, as a result of insightful model criticism, embellished the basic model to consider important elements like time and (latent) movie popularity.
- [method] Discrepancies that are hard to build into the model can still be easy to
  check on replicated data. `5.2` ^f8
  > Notice these would be difficult to build into the model, but they are easy to check in replicated data.
- [lab] Checked, not there: no procedure for ranking candidate revisions, no cost or
  power considerations, no evidence that criticism-led search beats trying
  alternatives. ^f9

## Read

- Abstract, section 1 (Box's loop), section 5 (5.1 predictive sample re-use, 5.2 PPCs),
  section 6 discussion; one paragraph of 3.3 (Netflix).

## Not read

- Sections 2 to 4 (model building blocks, graphical models, variational inference):
  latent variable machinery, not about choosing what to try.
