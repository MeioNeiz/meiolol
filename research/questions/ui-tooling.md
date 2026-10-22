---
status: answered
priority: now
area: ui
tags: [web, web/qa, ux]
description: What tooling lets meiolol's agents write and check better UI without a Node build step: layout and visual checks, component gallery, design token lints, accessibility?
---
# What tooling lets meiolol's agents write and check better UI without a Node build step: layout and visual checks, component gallery, design token lints, accessibility?

Feeds: docs/frontend-rework.md Option A steps 2, 3, 6 (CSS lint, components, QA script)

## Answer

Mature server-rendered shops hang every UI check on one list of component previews:
Primer runs axe, a screenshot plus focus state, and an ARIA snapshot per preview (C1).
For meiolol that list is a gallery page of ui.zig components in each state, rendered by
`meiolol dev`.

Stored-baseline screenshot tests are the expensive part: baselines only hold on the
machine that made them, false positives train reviewers to click approve, and Primer
switched its PR job off in Nov 2025 (C2, C3). Wikimedia's way avoids baselines: render
main and the patch in one run and diff (C4). Use that as review evidence, not a gate.

Deterministic layout checks give more per hour: the five common responsive failures
(element overlap, overflow of parent and of viewport, small-range layouts, wrapping)
hide between fixed check widths, so sweep widths (C5). axe catches most issue
instances but a minority of barrier kinds, and nothing flags colour-only meaning (C6);
its 24 px target-size rule is off by default.

CSS: enforce tokens with a per-property lint, switched on one property at a time (C7),
written as a Zig test so ci needs no Node; `@layer` works only if every rule is
layered and `!important` stays out (C8).

Agents grading their own UI praise it; a separate reviewer with a written rubric and
scored examples helps but still misses small layout bugs, so it sits on top of the
deterministic checks (C9). The 22 Oct audit (scratchpad, summarised in
zig-only-frontend) found exactly the bug kinds a width sweep and a cross-page number
check would catch, plus design inconsistencies only a rubric reviewer would flag.

Toolset (C10): Zig CSS lint and JS id check in ci; gallery page; deploy/qa.sh with
Playwright on the Mac (width sweep 320-1280, overflow, overlap, text under 11 px, tap
targets, console errors, axe with target-size on, ARIA snapshots as text); main vs
working-tree screenshot diffs shown, not gated; optional rubric reviewer session.

## Claims

- C1: Mature server-rendered teams use one list of component previews to drive screenshots, accessibility checks and ARIA snapshots. for: [[primer-view-components#^f2]], [[primer-view-components#^f3]], [[lookbook-guide#^f1]], [[phoenix-storybook-vrt#^f2]]
- C2: Stored-baseline screenshot tests cost a lot to maintain, even at GitHub and Wikimedia. for: [[primer-view-components#^f10]], [[wikimedia-vrt-T236722#^f1]], [[argos-flaky-visual-tests#^f1]]
- C3: Baselines only hold on one machine, so screenshot comparison belongs in one fixed environment. for: [[playwright-visual-comparisons#^f2]], [[argos-flaky-visual-tests#^f5]], [[wikimedia-pixel#^f3]]
- C4: Comparing two builds in the same run avoids keeping baselines. for: [[wikimedia-vrt-T236722#^f2]], [[wikimedia-pixel#^f1]]
- C5: Responsive layout failures fall in five types and often show only in narrow width ranges, so sweeping widths finds more than spot checks. for: [[walsh-redecheck-issta2017#^f1]], [[walsh-redecheck-issta2017#^f2]], [[walsh-redecheck-issta2017#^f3]]
- C6: Automated accessibility checks find a minority of barrier kinds but most issue instances; a clean run proves nothing. for: [[govuk-a11y-tool-audit#^f2]], [[deque-57-percent#^f3]], [[govuk-a11y-tools-blog#^f3]], [[playwright-a11y-testing#^f3]]
- C7: Mature teams enforce design tokens with a per-property lint, switched on one property at a time. for: [[mozilla-use-design-tokens#^f1]], [[mozilla-use-design-tokens#^f2]], [[stylelint-strict-value#^f1]]
- C8: `@layer` removes specificity fights only if every rule sits in a layer and `!important` is avoided. for: [[dialtone-cascade-layers#^f3]], [[dialtone-cascade-layers#^f4]], [[dialtone-cascade-layers#^f5]]
- C9: An LLM judging UI must be separate from the author and needs written criteria and examples; it still misses small layout issues. for: [[anthropic-harness-design#^f1]], [[anthropic-harness-design#^f3]], [[anthropic-harness-design#^f6]], [[uicrit-2024#^f1]], [[uicrit-2024#^f3]]
- C10 (inferred): For meiolol: gallery page, Zig CSS lint, Playwright width sweep plus axe on the Mac, unbaselined main-vs-tree diffs, optional rubric reviewer. from: C1, C3, C4, C5, C6, C7, C9

## Disagreements

Whether visual regression should gate merges: Playwright docs assume yes; Primer and
Wikimedia's experience says the gate rots. We follow the experience.

## Open

- Width sweep cost on the Mac across ~15 page types (minutes?) not measured
- Rubric and two scored example pages for a reviewer session not written
- Saturated: last 3 searches found nothing new. Leads: Argos on Playwright limits,
  UICrit follow-up (arXiv 2412.16829), VERVE (STVR 2020)
