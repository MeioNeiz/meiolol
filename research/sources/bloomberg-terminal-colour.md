---
title: 'Bloomberg: Designing the Terminal for Color Accessibility'
url: https://www.bloomberg.com/company/stories/designing-the-terminal-for-color-accessibility/
kind: article
commit: 
for: [ui-guardrails]
looked: 2026-10-22
depth: docs (whole article)
relevance: medium
grade: B/fair
description: Bloomberg UX research on colour-vision-deficient Terminal users: lab study (mixed models) and desk interviews; blue/red up/down scheme with amber kept for non-semantic information
---
# Bloomberg: Designing the Terminal for Color Accessibility

Why: how the densest data UI there is limits and assigns meaning-carrying colour, on a
dark background.

## Assessment

- Evidence: B. First-hand report by Bloomberg's UX team: lab study with linear mixed
  models plus desk interviews; no effect sizes or n published.
- Reasoning: fair. Explains the semantic constraints and why OS colour filters were not
  enough.
- Interests: company blog about its own product.
- Weigh: trust the qualitative findings by severity; numbers (20,000 CVD users) are
  estimates.

## Findings

- [ux/colour] Terminal colour roles: semantic up/down colours plus one fixed colour
  (amber) for non-semantic information; the CVD scheme swaps red/green for blue/red and
  keeps amber. Our solution ^f1
  > we chose to stick with a blue and red (“up” market status and “down” market status) CVD color scheme, while at the same time retaining the default Bloomberg amber color for non-semantic information.
- [ux/colour] Lab result: CVD clients were more accurate and more confident with
  alternative and high-contrast colour sets than with the default. Research process ^f2
  > clients were more accurate, reported greater confidence, and preferred the alternative and high contrast color sets compared to the current color set.
- [ux/colour] Even mild CVD struggles with colour carried by thin lines and small text;
  moderate CVD with darker colours on dark backgrounds. Research process ^f3
  > those who had a milder form of CVD tended to have fewer issues differentiating colors, but did have minor issues with differentiating between thinner red and green lines.
  > They also had more difficulty distinguishing between darker colors on dark backgrounds.
- [ux/colour] Semantic associations survive CVD: greens and blues read as up; reds,
  yellows and oranges as down. Research process ^f4
  > greens and blues tended to be self-reported as denoting an “up” market status, while reds, yellows, and oranges tended to denote a “down” market status.
- [ux/colour] (inferred) Supports meio.lol's blue above, orange below scale, and argues
  for vivid rather than dark steps on the dark theme and against colour carried only by
  small text. ^f5

## Read

- Whole article

## Not read

- Linked prevalence paper (pubmed 22472762)
