---
title: 'Memon et al. 2017: Taming Google-Scale Continuous Testing (ICSE-SEIP 2017)'
url: https://research.google.com/pubs/archive/45861.pdf
kind: paper
commit: 
for: [parallel-build-capacity]
looked: 2026-11-05
depth: docs (sections I-III, IV distance, VI)
relevance: high
grade: A/strong
description: Google TAP: affected tests by reverse build dependencies, run in milestones (batches of commits, every 45 min) because per-commit testing grew quadratically; 99% of affected test runs pass
---
# Memon et al. 2017: Taming Google-Scale Continuous Testing (ICSE-SEIP 2017)

Why: how does a large shop run only the tests a change can affect, and what does it lose?

## Assessment

- Evidence: A. Google's company-wide CI (2 billion lines, 150 million test runs a day),
  a month of data: over 500K changes, 5.5 million test targets, 4 billion outcomes.
- Reasoning: fair. Clear on what TAP does and why (cost growth); the empirical findings
  are correlations, and the authors say the exact numbers may not generalise.
- Interests: Google authors describing their own system.
- Weigh: the mechanism (reverse dependencies, then batching) is the transferable part;
  the distance and author findings are Google-specific.

## Findings

- [devflow/select] TAP picks AFFECTED tests by walking reverse build dependencies from
  the changed files to every test target that depends on them, directly or indirectly. II ^f1
  > rules to create a reverse dependency structure that eventually outputs all test targets that directly or indirectly depend on the modified files; these are called AFFECTED test targets.
- [devflow/select] Scale: 13K projects, 800K builds and 150 million test runs a day; a
  commit every second. I ^f2
  > more than 13K code projects, requiring 800K builds and 150 Million test runs.
- [devflow/select] [devflow/queue] Testing every commit grew quadratically (submission
  rate times test pool), so TAP batches commits into milestones. I ^f3
  > the compute resources were growing quadratically with two multiplicative linear factors
  > TAPs milestone strategy is to bundle a number of consecutive code commits together, and run (or cut) a milestone as frequently as possible given the available compute resources.
- [devflow/select] [devflow/queue] The cost: a milestone every 45 minutes at peak, so a
  developer waits at least that long for failures; up to 9 hours seen. I ^f4
  > A milestone is typically cut every 45 minutes during peak development time
  > we have observed unacceptably large delays of up to 9 hours.
- [devflow/select] Batching saves work because a test affected by several commits runs
  once, at its latest affecting commit; the rest stay AFFECTED unless run on demand. II ^f5
  > time and resources are saved with this approach because test targets are executed only at their latest affecting CL.
- [devflow/select] An average change's affected tests: almost half passed, 43% stayed
  AFFECTED (not run), 7.4% SKIPPED, under 0.5% failed. III, Table I ^f6
  > Of the remaining, 43% remained AFFECTED (not executed) and 7.4% were SKIPPED. Less than 0.5% FAILED.
- [devflow/select] Affected is far wider than failing: of 5.5 million affected tests only
  63K ever failed; 1.23% of executions found a breakage or fix; pass to fail 99:1. I ^f7
  > of the 5.5 Million affected tests that we analyzed for a time period, only 63K ever failed.
  > only a tiny fraction (1.23%) actually found a test breakage (or a code fix) being introduced by a developer.
- [devflow/select] Affected sets can reach 1.6 million tests for one change, and a
  milestone up to 4.2 million. IV, I ^f8
  > In our work, we have seen set sizes as large as 1.6 Million.
- [devflow/select] Tests more than 10 dependency edges from the change hardly ever break
  (a signal for skipping far tests; Google-specific). I ^f9
  > found that test targets that are more than a distance of 10 (in terms of number of dependency edges) from the changed code hardly ever break.
- [devflow/select] Files modified by 3 or more developers in a short span break things
  significantly more often than with 2. I ^f10
  > files within a short time span modified by 3 (or more) developers are significantly more likely to cause breakages compared to 2 developers.
- [devflow/select] Flakiness rules out "rerun recently failed tests" heuristics: they
  mostly rerun flaky tests. I ^f11
  > we could not rely on regression test selection heuristics such as “rerun tests that failed recently” [14] [15] as we would end up mostly re-running flaky tests [1].
- [devflow/select] The exact numbers (such as distance 10) may not hold elsewhere,
  especially in smaller codebases without deep dependencies. VI ^f12
  > They may not have deep Google-like dependencies in their relatively-smaller codebases.

## Read

- Abstract, I (introduction and findings list), II (TAP in a nutshell), III data
  characteristics, IV distance model, VI conclusions.

## Not read

- IV hypotheses on file types, users and tools in detail: correlations, not methods.
