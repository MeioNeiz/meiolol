---
title: The ML Test Score: A Rubric for ML Production Readiness (Breck et al., Google, 2017)
url: https://research.google.com/pubs/archive/46555.pdf
kind: paper
commit: 
for: [agent-ml-practice]
looked: 2026-10-13
depth: listed (whole paper bar related work)
relevance: high
grade: A/fair
description: Google's 28-test rubric (data, model, infrastructure, monitoring) for production ML, from interviews with 36 systems' maintainers, scored half a point manual and one point automated
---
# The ML Test Score (Breck, Cai, Nielsen, Salib, Sculley; IEEE Big Data 2017)

Why: which tests mature ML teams write for data, models and pipelines, and which of
them an experiment harness could run automatically per run.

## Assessment

- Evidence: A. Widely cited Google rubric (co-author of "Hidden Technical Debt");
  drawn from production systems and interviews with maintainers of 36 systems; a
  survey of several dozen Google teams.
- Reasoning: fair. Each test has a why and a how; no measurement of which tests catch
  the most bugs.
- Interests: Google practice; promises its own tooling (later TFX / TF Data
  Validation).
- Weigh: production serving focus (canaries, rollback, serving skew) is beyond an
  offline lab; the data tests, model tests and Infra 1-4 transfer directly.

## Findings

- [lab] Training is like compilation with code and data as source, so data needs
  tests like code. Section I ^f1
  > By that analogy, training data needs testing like code, and a trained ML model needs production practices like a binary does
- [lab] No test was done by more than 80% of surveyed Google teams, yet most had a
  nonzero score in at least half: worth doing but not obvious. Section I ^f2
  > in a survey of several dozen teams at Google, none of these tests was implemented by more than 80% of teams
- [lab] Data 1: encode expectations about features in a schema and check data against
  it automatically, in training and serving. Section II ^f3
  > It is useful to encode intuitions about the data in a schema so they can be automatically checked.
- [lab] Data 2: know each feature's added value independent of the others, e.g. by
  training models with one feature removed (leave-one-out ablation). Section II ^f4
  > by training a set of models that each have one of k features individually removed.
- [lab] Data 7: feature code needs unit tests; a feature bug present in both training
  and test data is almost impossible to detect later. Section II ^f5
  > Bugs in features may be almost impossible to detect once they have entered the data generation process, especially if they are represented in both training and test data.
- [lab] Model 1: every model spec is reviewed and checked in, so the exact code behind
  any trained model is known. Section III ^f6
  > when responding to production incidents, it’s crucial to know the exact code that was run to produce a given learned model.
- [lab] Model 5: test regularly against a very simple baseline (a linear model with
  few features), which also checks the pipeline works. Section III ^f7
  > Regularly testing against a very simple baseline model, such as a linear model with very few features, is an effective strategy both for confirming the functionality of the larger pipeline
- [lab] Model 6: check quality on important slices; a global gain can hide a large
  drop on one slice. Release tests: absolute threshold per slice and a maximum change
  versus the previous model. Section III ^f8
  > global accuracy improved by 1% but accuracy for one country dropped by 50%.
  > release tests for models can impose absolute thresholds (e.g., error for slice x must be <5%), to catch large drops in quality, as well as incremental
- [lab] Infra 1: training twice on the same data should give identical models;
  determinism enables diff-testing refactors. Nondeterminism sources: RNG (seed it),
  initialisation order, thread ordering of data. Section IV ^f9
  > Ideally, training twice on the same data should produce two identical models.
  > verifying that the old and new feature generation code will train to an identical model can provide more confidence that the refactoring was correct.
- [lab] Infra 2: a unit test that trains one gradient step on random input catches many
  library mistakes fast; also check loss decreases over a few iterations and that a
  model can memorise its training data. Avoid golden tests. Section IV ^f10
  > a simple unit test to generate random input data, and train the model for a single step of gradient descent is quite powerful for detecting a host of common library mistakes
  > Another solution involves not training to completion in the unit test but only training for a few iterations and verifying that loss decreases with training.
  > When testing models, pains should be taken to avoid “golden tests”
- [lab] Infra 3: an automated end-to-end pipeline test runs regularly, with a fast
  variant on a data subset or simpler model. Section IV ^f11
  > Faster running integration tests with a subset of training data or a simpler model can give faster feedback to developers
- [lab] Infra 4: an automated gate blesses or vetoes each trained model: loose
  thresholds against a validation set for slow decay, tight comparison to the
  previous model for sudden drops. Section IV ^f12
  > an automated system needs to inspect it and verify that its quality is sufficient; that system must either bless the model or veto it
- [lab] Monitor 3: training and serving code paths for the same feature must compute
  identical values; log serving examples and compare per feature. Section V ^f13
  > the feature values should be perfectly identical at training and serving time for the same example.
- [lab] Monitor 5: alert on the first NaN or infinity, implausible weight bounds, and
  dead-ReLU fraction during training. Section V ^f14
  > Explicitly monitor the initial occurrence of any NaNs or infinities.
- [lab] [stats] Monitor 7: calibration by slice as a canary (90% of 0.9 predictions
  should be positive); unbiased is not good, but bias flags a problem. Section V ^f15
  > Generally speaking, models should have zero bias, in aggregate and on slices (e.g. 90% of predictions of probability 0.9 should in fact be positive).
- [lab] Scoring: half a point for a test run by hand and documented, a full point if run
  automatically and repeatedly; the score is the minimum over the four sections. Section VI ^f16
  > A full point is awarded if there is a system in place to run that test automatically on a repeated basis.
- [lab] (inferred) Directly portable to meiolol-lab: a determinism check (same seed
  twice gives identical metrics, or a diff), a one-step and overfit-tiny-set unit test
  per net, a NaN/inf trip-wire, slice tables (by role, elo, patch) with calibration,
  and the "simpler model is not better" row. Infra 1 also gives a cheap refactor test:
  old and new feature code must train to identical models. ^f17

## Read

- Sections I to VI, the four test tables and the scoring table

## Not read

- Related work in detail, references
