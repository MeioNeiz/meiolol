---
title: 'GOV.UK Design System: Details component'
url: https://design-system.service.gov.uk/components/details/
kind: docs
commit: 
for: [ui-guardrails]
looked: 2026-10-22
depth: docs (whole page)
relevance: high
grade: A/fair
description: GOV.UK's details (native disclosure) component: reveal detail only some users need, never what most need; short descriptive link text; research shows some users avoid clicking it
---
# GOV.UK Design System: Details component

Why: the canonical guidance on folding explanation into a disclosure, and its limits.

## Assessment

- Evidence: A. GOV.UK Design System component with a change log back to 2021 and a
  research section fed by a public GitHub discussion.
- Reasoning: fair. When to use and not, choice against tabs and accordions, known
  research problems.
- Interests: none.
- Weigh: the "not for what most users need" rule is the guard against hiding numbers.

## Findings

- [ux/layout] Purpose: make the page easier to scan by revealing detail only if needed. Intro ^f1
  > Make a page easier to scan by letting users reveal more detailed information only if they need it.
- [ux/layout] Never hide what most users need. When not to use this component ^f2
  > Do not use the details component to hide information that the majority of your users will need.
- [ux/layout] Details for one section; less prominent than tabs and accordions, so for
  less important content. Decide between details, accordions and tabs ^f3
  > The details component is less visually prominent than tabs and accordions, so tends to work better for content which is not as important to users.
- [ux] The summary link text is short and descriptive. Write clear link text ^f4
  > Make the link text short and descriptive so users can quickly work out if they need to click on it.
- [ux/layout] Research: some users don't click it, thinking it leaves the page; some voice
  software can't operate it. Research on this component ^f5
  > There is evidence that some users avoid clicking the link to show more details, as they think it will take them away from the page.
- [ux/layout] (inferred) Folding method text into details is safe only for content most
  players skip; numbers and anything needed to read them stay outside. ^f6

## Read

- Whole page

## Not read

- The GitHub discussion 6095 research comments
