---
title: 'technicalities: "not rocket science" (the story of monotone and bors), Graydon Hoare 2014'
url: https://web.archive.org/web/20240101105019/https://graydon2.dreamwidth.org/1597.html
kind: article
commit: 
for: [parallel-build-capacity]
looked: 2026-11-05
depth: docs (whole post and comments)
relevance: medium
grade: A/fair
description: Origin of the Not Rocket Science Rule and the first bors: test the merged result, advance main only if it passes
---
# technicalities: "not rocket science" (the story of monotone and bors), Graydon Hoare 2014

Why: the canonical statement of the rule every merge queue enforces, and what it costs.
Live URL 404s now; archived copy (2024-01-01).

## Assessment

- Evidence: A. Canonical reference by the author of Rust's bors; the rule became bors,
  Homu, bors-ng and GitHub merge queue.
- Reasoning: fair. States the rule and its cost (cycle time bounded by test time) but
  no numbers.
- Interests: none.
- Weigh: the rule and the order (integrate, test, then advance) are the point; the
  one-at-a-time bors it describes is what later systems batch to scale.

## Findings

- [devflow/queue] The rule: automatically maintain a repository of code that always
  passes all the tests. ^f1
  > automatically maintain a repository of code that always passes all the tests
- [devflow/queue] Common CI does it in the wrong order: accept before testing, or test
  in isolation and integrate on that result with no guarantee the combination works. ^f2
  > code being accepted _before_ testing (leaving a potentially broken tree), or tested in isolation and then integrated on the basis of that test (with no guarantee that the integrated combination works)
- [devflow/queue] Bors makes a temporary integration revision (main plus the change),
  tests it, and advances main to it only if the tests pass; on failure the revision is
  discarded and the failures posted to the PR. ^f3
  > makes a _temporary integration revision_ which extends your integration branch by the proposed changes. It tests that temporary revision and advances your integration branch to point to the integration revision if and only if the tests pass
- [devflow/queue] Cost: integration cycle time is bounded by test cycle time, and some
  changes take several attempts (priority markers tune the order by hand). ^f4
  > It does mean that your integration cycle time is bounded by your test cycle time, and it means that some changes take a number of attempts to integrate
- [devflow/queue] Trunk is never broken; beneficial on a fast-moving, delicate
  project. ^f5
  > Its effect on a fast-moving, delicate project is extremely beneficial. Trunk is never broken.
- [devflow/queue] Long test times are the chief objection; his answer is an
  integration-test subset if needed, but try it anyway. ^f6
  > On some projects, test time is too long for this strategy to work on each revision, at least without defining an integration-test subset.

## Read

- Whole post and comments.

## Not read

- graydon/bors source (the original script).
