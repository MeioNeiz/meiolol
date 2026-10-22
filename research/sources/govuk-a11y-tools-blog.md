---
title: 'GOV.UK accessibility blog: What we found when we tested tools on the world''s least-accessible webpage (2017)'
url: https://accessibility.blog.gov.uk/2017/02/24/what-we-found-when-we-tested-tools-on-the-worlds-least-accessible-webpage/
kind: article
commit: 
for: [ui-tooling]
looked: 2026-10-22
depth: listed
relevance: medium
grade: A/fair
origin: govuk-a11y-tool-audit
description: GDS blog on its tool audit: 29% of barriers missed by every tool (colour-only links, empty table cells), tools like a spellchecker, combine with manual checks
---
# GOV.UK accessibility blog: What we found when we tested tools on the world's least-accessible webpage (2017)

Why: what kinds of barrier automated tools miss.

## Assessment

- Evidence: A. Same GDS audit as govuk-a11y-tool-audit (origin), written up by its team.
- Reasoning: fair. Plain about limits.
- Interests: none.
- Weigh: the examples of missed barriers are the useful part.

## Findings

- [web/qa] 42 of 143 barriers (29%) were missed by every tool, including links identified
  by colour alone and tables with empty cells. Lots of the barriers ^f1
  > Of the 143 barriers we created, a total of 42 were missed by all of the tools we tested. The ones that were missed included barriers such as italics used on long sections of text, tables with empty cells and links identified by colour alone.
- [web/qa] Tools together caught 71%; no single tool came close. How best to use ^f2
  > While the tools picked up the majority of the accessibility barriers we created – 71% – there was a large minority that would only have been picked up by manual checking.
- [web/qa] A clean run proves nothing: treat a checker like a spellchecker. Pros and cons ^f3
  > just because a tool hasn’t picked up any accessibility issues on a website, doesn’t mean those issues don’t exist.
- [web/qa] [ux/colour] (inferred) meiolol's colour-coded win rate cells are the kind of
  barrier no tool flags; colour meaning needs a human or agent look. ^f4

## Read

- Post; first comments

## Not read

- Remaining comments
