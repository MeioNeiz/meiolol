---
title: 'Machalica et al. 2019: Predictive Test Selection (Facebook, ICSE-SEIP 2019)'
url: https://arxiv.org/pdf/1810.05286v2
kind: paper
commit: 
for: [parallel-build-capacity]
looked: 2026-11-05
depth: docs (sections I-III, V, VI results)
relevance: high
grade: A/strong
description: Facebook's learned test selection over build-dependency selection; half the CI cost, 95% of test failures and 99.9% of faulty changes still caught, the rest left to a full run every few hours
---
# Machalica et al. 2019: Predictive Test Selection (Facebook, ICSE-SEIP 2019)

Why: how does a large shop run only the tests a change can affect, and what does it lose?

## Assessment

- Evidence: A. Deployed in production at Facebook for several months on the mobile
  monorepo (tens of thousands of changes a week); the canonical paper on predictive
  selection, widely cited.
- Reasoning: strong. Lays out the spectrum (build graph, static, dynamic, learned), which
  are sound and which approximate, the cost/latency/risk trade-off, and the flakiness
  problem.
- Interests: authors' own system; numbers are self-reported, no external replication.
- Weigh: trust the structure (sound graph selection, then cheaper approximate selection
  backed by a periodic full run); the ML part needs history we don't have.

## Findings

- [devflow/select] Baseline at Facebook: run every test that transitively depends on a
  changed file in the build graph; strict build isolation makes this sound. I ^f1
  > A common change-based test selection strategy is to choose tests that transitively depend on modified code according to build dependencies
  > strict build isolation enforced by the build system guarantees this technique identifies all tests that could possibly be impacted by the change.
- [devflow/select] Its weakness is volume: about 10^4 tests per change, though most changes
  touch a few files. I ^f2
  > A major disadvantage of this approach is the number of tests selected on code changes
  > This is despite a vast majority of code changes touching only a few files and altering low-hundreds in lines of code.
- [devflow/select] Dynamic (coverage-based) and learned selection are approximate: they
  can miss tests that would catch the regression; only build-graph selection is safe. I ^f3
  > Note that all dynamic methods must be treated as approximate, in a sense that they may ignore tests that would detect regression in a particular change.
- [devflow/select] Result: fewer than a third of the build-graph tests, half the
  infrastructure cost, over 95% of test failures and 99.9% of faulty changes still
  reported. Abstract, I ^f4
  > The test selection procedure selects fewer than a third of the tests that would be selected on the basis of build dependencies
  > the strategy reduces the total infrastructure cost of testing code changes by a factor of two, while guaranteeing that over 95% of individual test failures and over 99.9% of faulty changes are still reported back to developers.
- [devflow/select] What makes the loss acceptable: a stabilisation run of all tests every
  few hours on master catches what selection missed. II-B4, VI ^f5
  > Once every few hours, all tests are exercised on the most recent version of master branch.
  > Note that any faulty change that makes it into the master branch will be detected in the stabilization stage.
- [devflow/select] [devflow/queue] Stage costs: diff- and land-time testing need an order
  of magnitude more machines than stabilisation and scale with the number of developers;
  their purpose is developer productivity, not release safety. II-B ^f6
  > Out of all discussed stages of automated testing, diff- and land-time ones require an order of magnitude more machine resources than testing during the stabilization stage.
  > Presence of the stabilization stage means the main goal of diff- and land-time testing is to boost developer productivity at an additional infrastructure cost, rather than to reduce risk of buggy software being released.
- [devflow/select] Almost all selected tests pass (about 99.9%), so most of the testing
  cost buys no signal. III-B ^f7
  > Since almost 99.9% of test targets selected by build-dependencybased selection strategy pass, selecting fewer passing tests could greatly reduce the resources consumed by testing.
- [devflow/select] The cost of testing less: developers hear of breakage later, at worst
  hours later at stabilisation, and must context-switch back. II-B ^f8
  > Less thorough testing at diff- and land-time would cause developers to learn about errors that need to be corrected at a later time, in the extreme case at the stabilization phase.
- [devflow/select] Two top-ranked tests catch at least one failure on 70% of faulty
  changes; at most 230 targets per change versus an average of over 1000 dependents. VI,
  Fig. 7 ^f9
  > This is due to the model being able to capture at least one failure on 70% of faulty changes by selecting only two highest-scoring test targets.
- [devflow/select] Flaky tests poison training data; failures are de-flaked by retrying,
  and running more tests surfaces more flaky failures. V ^f10
  > If we train our classifier on flaky test results, we get very poor predictions.
- [devflow/select] (inferred) For meiolol: one module graph in build.zig, so build-graph
  selection maps to "which test steps depend on the changed files"; the safe-plus-periodic
  pattern is selected tests before push, full `zig build ci` on a timer or batch. ^f11

## Read

- Sections I-III, V, VI (results and calibration): closely.

## Not read

- Section IV features and model details (gradient boosted trees on change and test
  features): needs a long test-outcome history we lack.
