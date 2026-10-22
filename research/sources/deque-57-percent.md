---
title: 'Deque: automated testing identifies 57% of digital accessibility issues (2021)'
url: https://www.deque.com/blog/automated-testing-study-identifies-57-percent-of-digital-accessibility-issues/
kind: article
commit: 
for: [ui-tooling]
looked: 2026-10-22
depth: listed (press release; full report not read)
relevance: medium
grade: B/weak
description: Deque press release: across 2,000+ audits and ~300k issues, axe-core automated checks fully covered 57% of issues by volume, against the usual 20-30% by success criteria
---
# Deque: automated testing identifies 57% of digital accessibility issues (2021)

Why: what share of accessibility issues axe-core (the engine of @axe-core/playwright)
catches.

## Assessment

- Evidence: B. Large real dataset (2,000+ audits, 13,000 pages, ~300k issues), but a
  press release; method only in a gated report.
- Reasoning: weak here. The number moves from 20-30% to 57% by changing the denominator
  (issue volume, not criteria), which it states openly.
- Interests: vendor of axe; the coverage figure sells its tools.
- Weigh: trust that common issues are the automatable ones; read 57% as "share of issue
  instances on typical sites", not "share of kinds of problem".

## Findings

- [web/qa] Dataset: 2,000+ first-time audits, 13,000 pages, nearly 300,000 issues, tested
  with axe-core. Study synopsis ^f1
  > Deque’s study used anonymized data from over 2,000 audits in various industries, spanning over 13,000 pages (all first-time page assessments) covering nearly 300,000 issues.
- [web/qa] On average 57% of issues were fully covered by automated testing. Synopsis ^f2
  > Deque found that, on average, 57 percent of accessibility issues were completely covered by this automated testing.
- [web/qa] The usual 20-30% figure counts WCAG success criteria; Deque counts issue volume,
  where frequent issue types are the automatable ones. Redefining ^f3
  > some types of issues occur much more frequently than others, which can result in a much higher percentage of total accessibility issues discovered using automated tools.
- [web/qa] axe-core is built to avoid false positives, so a clean axe run is low noise
  but not complete. Redefining ^f4
  > the axe-core rules library places a huge emphasis on not reporting false positives or erroneous issues.

## Read

- Press release

## Not read

- Full coverage report (deque.com/coverage-report, gated)
