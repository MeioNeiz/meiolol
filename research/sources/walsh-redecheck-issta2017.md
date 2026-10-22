---
title: 'Walsh, Kapfhammer, McMinn 2017: ReDeCheck: An Automatic Layout Failure Checking Tool for Responsively Designed Web Pages (ISSTA 2017)'
url: https://eprints.whiterose.ac.uk/id/eprint/116991/1/c49.pdf
kind: paper
commit: 
for: [ui-tooling]
looked: 2026-10-22
depth: listed (5-page tool paper)
relevance: high
grade: B/strong
description: Sheffield tool paper: five common responsive layout failure types (collision, element and viewport protrusion, small-range layouts, wrapping), found in over half of 26 production pages; failures often live at a few widths only
---
# Walsh, Kapfhammer, McMinn 2017: ReDeCheck (ISSTA 2017)

Why: which layout failures are worth asserting automatically, beyond pixels.

## Assessment

- Evidence: B. Peer-reviewed (ISSTA tool track), measured on 26 production pages and 100
  mutated pages; the line of work won an IEEE distinguished paper award later. Java and
  Selenium tool, research grade.
- Reasoning: strong. Reports false positives and non-observable issues, compares with
  Galen and spot checks.
- Interests: authors' own tool.
- Weigh: trust the failure taxonomy and the "bugs hide between breakpoints" finding; the
  tool itself is not something to adopt.

## Findings

- [web/qa] Five common responsive layout failures: element collision, element and
  viewport protrusion, small-range layouts, wrong wrapping. Section 2 ^f1
  > types are, namely, element collision (two elements overlapping),
  > their container or the viewport, respectively), small-range layouts
- [web/qa] Failures often occur only over small, unpredictable width ranges, so spot
  checks at fixed widths (320, 768, 1024) miss them. Introduction ^f2
  > Since RLFs often occur intermittently at
  > unpredictable and occasionally small ranges of viewport widths,
- [web/qa] Well over half of 26 random production pages had layout failures, including
  Duolingo, and a manual spot check missed Duolingo's. 3.1 ^f3
  > Well over half of the web pages,
- [web/qa] Method: extract element positions and alignments across widths, binary-search
  the widths where layout changes, then check each layout. Section 2 ^f4
  > layouts, the tool conducts a binary search to ﬁnd the exact viewport
- [web/qa] False positives exist (rows misread as wrapping); some DOM overlaps are not
  visible (non-observable issues). 3.1 ^f5
  > of DOM coordinates — the elements are, for example, overlapping,
- [web/qa] Galen, by contrast, needs hand-written layout specs per page (an explicit
  oracle). Section 4 ^f6
  > requires the developer to write tests with one or more oracles.
- [web/qa] (inferred) For meiolol's qa script: assert collision, protrusion past the
  viewport and past the parent (scrollWidth > clientWidth on non-scrolling boxes) over a
  sweep of widths (e.g. 320 to 1280 in steps), not only 390 and 1280. ^f7

## Read

- Whole paper (5 pages)

## Not read

- The full-length studies it cites ([18], [19]); the STVR 2020 VERVE follow-up
