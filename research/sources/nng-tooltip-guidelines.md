---
title: 'NN/g: Tooltip Guidelines (Kendrick, 2019)'
url: https://www.nngroup.com/articles/tooltip-guidelines/
kind: article
commit: 
for: [ui-guardrails]
looked: 2026-10-22
depth: docs (whole article)
relevance: high
grade: A/fair
description: NN/g's tooltip rules: never task-critical information, brief non-redundant text, keyboard as well as mouse, consistent use; hover tooltips don't exist on touchscreens
---
# NN/g: Tooltip Guidelines (Kendrick, 2019)

Why: how far explanation can move into tooltips before it is lost.

## Assessment

- Evidence: A. NN/g guideline article built on usability-study examples (Amtrak, FedEx,
  Sprint, Alibaba).
- Reasoning: fair. Each rule has a do and a don't; no measurements.
- Interests: NN/g sells courses.
- Weigh: the touchscreen point matters most for meio.lol's phone readers.

## Findings

- [ux/layout] Never put task-critical information in a tooltip; tooltips vanish. Guideline 1 ^f1
  > Don’t use tooltips for information that is vital to task completion.
- [ux] Brief and not redundant; no helpful content means no tooltip. Guideline 2 ^f2
  > If you can’t think of particularly helpful content, don’t offer a tooltip.
- [ux] Long content is no longer a tip: tooltips are self-sufficient microcontent. Guideline 2 ^f3
  > lengthy content is no longer a ‘tip’, so keep it brief.
- [ux/layout] Hover tooltips are unavailable on touchscreens; popup tips are the touch
  equivalent. Defining Tooltips ^f4
  > They are not normally available on touchscreens.
- [web/qa] Tooltips must open on keyboard focus too. Guideline 3 ^f5
  > Tooltips that appear only on mouse hover are inaccessible for users that rely on keyboards to navigate.
- [ux] Use tooltips consistently or not at all; erratic tooltips are never discovered. Guideline 5 ^f6
  > If tooltips are erratically displayed throughout your site, people may never discover them.
- [ux/layout] Minimalism moves work to the user: the more stripped, the more tooltips. Conclusion ^f7
  > The more we strive for extreme minimalism, the more tooltips we’ll need, and the more work for our users.
- [ux/layout] Test: needed to complete the task means on the screen, not in a tooltip. Conclusion ^f8
  > Important information should always be on the page; therefore, tooltips shouldn’t be essential for the tasks users need to accomplish on your site.
- [ux/layout] (inferred) Cutting words on meio.lol must not move what a player needs to
  read a number (its game count, what the column is) into hover text: phone readers
  can't hover. Definitions of terms can go into tap-to-open toggletips. ^f9

## Read

- Whole article

## Not read

- Popup tips comparison table in full (HTML table truncated in the snapshot)
