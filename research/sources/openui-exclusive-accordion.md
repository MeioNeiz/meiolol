---
title: 'Open UI: Exclusive Accordion explainer (details name)'
url: https://open-ui.org/components/accordion.explainer
kind: spec
commit: 
for: [zig-only-frontend]
looked: 2026-10-22
depth: listed (whole explainer)
relevance: medium
grade: A/strong
description: David Baron's Open UI explainer (2023, updated Aug 2026) for the details name attribute: what exclusive accordions do, what they deliberately leave out (exactly-one-open, roles, keyboard, tabs)
---
# Open UI: Exclusive Accordion explainer (details name)

Why: can `<details name>` replace our JS tabs and accordions, and what did its
designers deliberately leave out?

## Assessment

- Evidence: A. The design document behind the shipped feature (WHATWG PR 9400),
  by the Chromium engineer who specified it.
- Reasoning: strong. Open questions, alternatives considered and their problems.
- Interests: proposer of the feature.
- Weigh: trust its scope statements; they say what the feature is not.

## Findings

- [web] `details` elements sharing a `name` form a group: opening one closes the
  others, with the same matching rules as radio groups. ^f1
  > any user action or API that causes one of the `details` elements in the group to open causes all other elements in the group to close.
- [web] Accordions where exactly one item is always open (the tabs shape) are not
  covered; they need JS. ^f2
  > For now, do not attempt to address this pattern directly, but make sure it’s possible to do in Javascript.
- [web] No change to ARIA roles or keyboard behaviour: a named group is still a
  sequence of disclosures, not a tablist. ^f3
  > it seems like at least default keyboard behavior for accordions is undesirable because it leads to bad user experience particularly for users on small or highly-zoomed displays
- [web] Tabs were a separate proposal (panelset, spicy sections) with too many open
  questions; the explainer does not claim to solve tabs. ^f4
  > The panelset proposal has enough open questions that it’s a bit hard to assess.
- [web] Exclusivity is not enforced on parsed HTML: several `open` details with the
  same name in server markup stay open. ^f5
  > Do not enforce exclusivity when the `open` attribute is set by the parser
- [web] Printing all items open needs JS (beforeprint) once items are grouped. ^f6
  > they need to change both `name` and `open` attributes during the [`beforeprint`]
- [web] Known details issues remain: interactive content inside `summary`, and the
  heading versus summary relationship; it links Roselli's and Rupert's critiques. ^f7
  > there are issues related to interactive content in the `summary` element causing various keyboard and accessibility issues.

## Read

- Whole explainer

## Not read

- Linked critiques: Details / Summary Are Not [insert control here] (Roselli 2019),
  Why details is Not an Accordion (Rupert 2019); html-aam#509 on group naming
