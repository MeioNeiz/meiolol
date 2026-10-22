---
title: 'GDS accessibility team: Accessibility tools audit results (2017, updated 2018)'
url: https://alphagov.github.io/accessibility-tool-audit/
kind: dataset
commit: 
for: [ui-tooling]
looked: 2026-10-22
depth: docs (overview page)
relevance: medium
grade: A/fair
description: GOV.UK planted 142 barriers on one page and ran 13 automated checkers: best found 40%, axe 29% (30% with prompts); tools dated 2018
---
# GDS accessibility team: Accessibility tools audit results (2017, updated 2018)

Why: an independent measure of what automated accessibility checkers catch.

## Assessment

- Evidence: A. Government team, open method and test page on GitHub, widely cited.
- Reasoning: fair. Deliberate barriers include ones no tool could catch (plain language,
  flashing), so per-kind coverage is a floor; tool versions are 2018.
- Interests: none.
- Weigh: per-kind coverage, not per-instance; complements Deque's per-volume 57%.

## Findings

- [web/qa] Method: 142 deliberate barriers on one page, 13 tools. Overview ^f1
  > We deliberately introduced 142 accessibility barriers to a page of content, and ran them through 13 automated tools.
- [web/qa] Best tool found 40%, worst 13%; with manual-check prompts the best reached 50%.
  What we found ^f2
  > The best performing tool in this category found 40% of the problems we introduced. Whereas the worst performing tool only picked up 13% of the barriers.
- [web/qa] aXe: 29% of barriers found, 30% counting potential barriers (2018 version).
  Table ^f3
- [web/qa] aXe free, open source, CI, CLI and scriptable, guidance rated Good. Features ^f4
  > | aXe | Free | Free | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Good |

## Read

- Overview page

## Not read

- Per-barrier results (results.html) and test cases: which kinds axe misses
