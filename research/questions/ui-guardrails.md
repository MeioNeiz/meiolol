---
status: answered
priority: now
area: ui
tags: [ux, web/qa]
parent: ui-tooling
description: How do design systems keep a UI terse, uncluttered, clear and consistently coloured as many contributors add to it, and which of those rules can be checked automatically?
---
# How do design systems keep a UI terse, uncluttered, clear and consistently coloured as many contributors add to it, and which of those rules can be checked automatically?

Feeds: docs/design-ideas.md principles (exist, not enforced); docs/frontend-rework.md
Option A components and checks. Jacob 22 Oct: "WAAAAY too wordy", wants engaging,
space efficient, clear, not overwhelming, good colour; region picker buttons tiny

## Answer

The design rules in docs/design-ideas.md are mostly right; what's missing is enforcement,
and the evidence says enforcement is what keeps a UI terse once many people add to it.

Words: halving text and making it scannable measurably helps, and most users scan (C1).
Nobody publishes per-label limits, only prose limits (25-word sentences, 65-character
titles, 1-2 word icon tooltips), so meio.lol sets its own (C2). Explanations go one level
down, never two, and never hide what reading a number needs; on phones hover doesn't
exist, so a tap toggletip or details, and column terms as dotted-underline definitions
(C3).

Density: dense stays calm through hierarchy (one prominent number, subdued chrome,
minimal precision, every number with a comparison), not fewer numbers; tables beat
cards for comparing (C4). Sizes: 44 px tap targets on phones (24 px is only the AA
floor; padding can grow the hit area), no text under 11 px, about five sizes (C5, C6).
Colour: neutral by default, saturated colour only from role tokens and only for
meaning; accuracy falls as hues are added (C7). Blue against orange is contested for
colour-blind readers, so the second cue beside colour is required, not optional.

Engagement: the backed levers are personal relevance (the visitor's own champion,
region, place in the chart) and predict-then-reveal (C8): Daily Draft and Learn already
use the second; the stats pages ignore the first.

Enforcement: teams lint tokens, text size, target size and wordy prose; tone, hierarchy
and "is this needed" stay with a second reader (C9). Roll each check in as a warning,
fix existing hits, then make it an error, with a stated reason on any exception (C10).
For us many checks can be compile errors in Zig components (label length, one answer
cell per row, a second cue on coloured cells), the rest in the Playwright sweep
(ui-tooling C10) and a rubric reviewer. Draft guardrails: docs/frontend-rework.md
"Guardrails".

## Claims

- C1: Halving words and making text scannable measurably improves usability; most users scan. for: [[nng-how-users-read#^f4]], [[nng-how-users-read#^f1]], [[nng-f-pattern#^f1]]
- C2: Mature systems give numeric limits only for prose and icon tooltips; label limits are left to each team. for: [[govuk-clear-language#^f1]], [[govuk-clear-titles#^f1]], [[carbon-tooltip#^f2]], [[polaris-content#^f10]]
- C3: Explanations go one level down, never more than two, and never hide what most users need or what reading a number needs; hover tooltips don't exist on touch. for: [[nng-progressive-disclosure#^f4]], [[nng-progressive-disclosure#^f6]], [[govuk-details-component#^f2]], [[polaris-content#^f8]], [[nng-tooltip-guidelines#^f4]], [[m3-tooltips-guidelines#^f4]], [[carbon-tooltip#^f4]]
- C4: Dense displays stay readable through hierarchy, consistent forms and minimal precision, not fewer numbers; tables beat cards for comparing. for: [[few-dashboard-pitfalls#^f6]], [[few-dashboard-pitfalls#^f4]], [[few-dashboard-pitfalls#^f3]], [[nng-data-tables#^f1]]
- C5: Phone tap targets should be 44 px or more; 24 px is only the AA floor, and padding can enlarge the hit area. for: [[wcag22-target-size-minimum#^f1]], [[wcag22-target-size-enhanced#^f1]], [[apple-hig-accessibility#^f1]], [[m3-accessible-structure#^f1]], [[m3-accessible-structure#^f2]]
- C6: No text below 11 px, and about five distinct sizes. for: [[apple-hig-typography#^f2]], [[mdc-android-typography#^f1]], [[m3-type-scale#^f3]], [[android-lint-smallsp#^f1]]
- C7: Most of the UI stays neutral; saturated colour carries meaning, comes from role tokens, and hues are few. for: [[atlassian-color#^f1]], [[atlassian-color#^f3]], [[few-rules-colour#^f2]], [[haroz-whitney-2012#^f4]], [[few-dashboard-pitfalls#^f7]], [[bloomberg-terminal-colour#^f1]]
- C8: Personal relevance and predict-then-reveal are the evidence-backed ways to make data engaging. for: [[peck-data-is-personal-2019#^f1]], [[kim-explaining-gap-2017#^f1]], [[kim-explaining-gap-2017#^f4]]
- C9: Teams lint tokens, text size, target size and wordy prose; tone, hierarchy and necessity stay with a human second reader. for: [[atlassian-eslint-token-usage#^f3]], [[stylelint-polaris#^f1]], [[android-lint-smallsp#^f1]], [[atf-touch-target#^f1]], [[gitlab-vale-rules#^f1]], [[gitlab-vale-testing#^f4]], [[govuk-2i-blog-2017#^f2]]
- C10: Checks roll out as warnings, existing hits get fixed, then they become errors; new exceptions state a reason. for: [[gitlab-vale-testing#^f3]], [[stylelint-polaris#^f3]], [[stylelint-polaris#^f4]], [[android-lint-smallsp#^f3]]
- C11: Blue against orange is contested for colour-blind readers. for: [[bloomberg-terminal-colour#^f4]] against: [[apple-hig-accessibility#^f4]]

## Disagreements

- Blue/orange: Apple lists it as a hard pair for colour-blind users; Bloomberg found
  colour-blind users still read blue as up, orange as down. Contests dense-stat-layout
  C4. Settle by a colour-blind simulation pass on our scale; keep the sign and bar cue.

## Open

- Word budget per page and label lengths are our own numbers; check them against the
  redesigned champion page before making them errors
- Leads: Borkin 2015 (titles and recall), Bloomberg "conceal complexity", NN/g mobile
  tables, Carbon toggletip, Atlassian data-vis colour. Discovery still growing (26)
