---
title: Catch Flakes On Main (matklad, 2026-05-14)
url: https://matklad.github.io/2026/05/14/catch-flakes-on-main.html
kind: article
commit: 
for: [zig-testing]
looked: 2026-10-22
depth: docs (whole post)
relevance: low
grade: B/fair
description: With a merge queue, keep re-running the full suite on main; every main failure is a flake by definition, list them to eradicate
---
# Catch Flakes On Main (matklad, 2026-05-14)

Why: test suite health. Version neutral.

## Assessment

- Evidence: B. TigerBeetle devhub "Flakes" list.
- Reasoning: fair.
- Interests: none.
- Weigh: meiolol tests on pre-push, not a merge queue; the idea maps to a log of
  failures on main.

## Findings

- [zig/test] Keep running the full suite on main and keep a list of recent main
  failures: these are the flakes to eradicate. ^f1
  > continue to redundantly run the full test suite on main. Maintain an easily accessible list of recent main failures — these are the flaky tests to eradicate.
- [zig/test] If every main commit passed the tests, every main failure is a flake by
  definition. ^f2
  > if there’s a guarantee that every commit on the main branch passes the tests, then every failure on main is a flake, by definition.

## Read

- Whole post.
