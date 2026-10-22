---
title: "Hidde de Vries and Scott O'Hara: On popover accessibility, what the browser does and doesn't do"
url: https://hidde.blog/popover-accessibility/
kind: article
commit: 
for: [zig-only-frontend]
looked: 2026-10-22
depth: listed (main post, updated 15 Mar 2025)
relevance: high
grade: A/strong
description: Two Open UI and accessibility specialists list exactly which semantics and keyboard behaviour the popover attribute adds (aria-expanded, aria-details, group role, focus return, tab order) and what it leaves to the author; Safari gaps noted
---
# Hidde de Vries and Scott O'Hara: On popover accessibility

Why: if meiolol swaps JS dropdowns and tooltips for `popover` plus `popovertarget`,
what accessibility do we get for free and what is still on us?

## Assessment

- Evidence: A. Scott O'Hara (Microsoft Edge, HTML-AAM editor) and Hidde de Vries
  (Open UI participant, ex W3C WAI); tested in JAWS and NVDA with demos.
- Reasoning: strong. Separates behaviour from semantics; names per-browser gaps.
- Interests: none; both worked on the feature.
- Weigh: browser specifics date from March 2025; Safari's gaps may have closed
  since (not checked).

## Findings

- [web] popover adds behaviour, not a role: the author still picks the element or
  role (menu, tooltip, list of links). ^f1
  > The thing with the popover attribute is that it doesn’t have a built-in role.
- [web] With a declarative `popovertarget` button the browser sets aria-expanded on
  the invoker; it does not when script opens the popover. ^f2
  > the state won’t be applied if script, rather than the declarative attribute, does the opening on click of any button
- [web] Browsers return focus to the invoker on close and, on desktop, put popover
  content right after the invoker in tab order. ^f3
  > Edge/Chrome, Firefox and Safari will all return focus to the invoking element when you close the popover (only if you are inside of it).
  > Desktop browsers also do something else: they add the popover content into the tab order just after the invoking button.
- [web] Beyond that the browser does nothing: keyboard patterns of the component
  (arrow keys in a menu, etc.) are the author's job. ^f4
  > the browser will not do _anything_ apart from the behaviours listed above.
- [web] Safari exposed less: aria-expanded only, no aria-details link and no group
  role fallback (as of March 2025). ^f5
  > Safari only sets `aria-expanded`, not `aria-details`. It also doesn't add a `group` role fallback.
- [web] (inferred) Script-driven popovers lose the free aria-expanded, so the
  declarative attribute is the more accessible path, not only the shorter one. ^f6

## Read

- Main post; the appended positioning post only skimmed

## Not read

- Scott O'Hara, Popping preconceived popover ponderings (2025); Hidde, popover
  semantics; dialog vs popover differences
