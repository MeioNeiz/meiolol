---
title: 'Adrian Roselli: CSS-only Widgets Are Inaccessible'
url: https://adrianroselli.com/2023/03/css-only-widgets-are-inaccessible.html
kind: article
commit: 
for: [zig-only-frontend]
looked: 2026-10-22
depth: listed (whole post, updated 21 Apr 2026)
relevance: high
grade: A/strong
description: Accessibility consultant's running catalogue (2023, updated to Apr 2026) of CSS-only widgets and why they fail WCAG: checkbox disclosures, :has() on selects, CSS sorting, radio tabs, animated details, radio state machines
---
# Adrian Roselli: CSS-only Widgets Are Inaccessible

Why: the critic's view. Which script-free patterns fail screen reader and keyboard
users, and where is CSS-only acceptable?

## Assessment

- Evidence: A. Long-standing, widely cited accessibility consultant (W3C WG member);
  each example tested with assistive tech (JAWS video for sorting), WCAG criteria named.
- Reasoning: strong. Names the failing success criterion and the fix for each case;
  admits exceptions exist.
- Interests: none commercial; a strong prior against CSS-only.
- Weigh: trust the per-pattern failures. It critiques CSS hacks (checkbox, radio,
  :has, order), not native HTML widgets (details, dialog, popover), which carry their
  own semantics.

## Findings

- [web] The core problem: CSS-only widgets show state visually but cannot pass state,
  relationships or names to accessibility APIs. ^f1
  > While CSS is ideal to show these visually, they need to be passed to accessibility APIs so they can be conveyed to users of assistive technologies.
- [web] Checkbox-hack disclosures: screen reader users hear an unexplained checkbox
  and Enter does not fire it; the fix is a button with aria-expanded, which needs
  script. ^f2
  > A screen reader user would have no idea why there is a checkbox.
  > In short, script is needed to manage the expanded or collapsed state
- [web] :has() on a select to drive other UI carries the same risk as the checkbox
  hack. ^f3
  > using `:has()` with select menus brings the same risk as the checkbox hack.
- [web] CSS sorting (order or grid placement) changes only the visual order: in JAWS
  the row positions and navigation order never change, violating meaningful sequence
  and focus order; real sorting reorders the DOM and sets aria-sort on a button in
  the header. ^f4
  > Visually the table rows are sorted, but their row position announcement and navigation order never changes.
  > the sorting operation would restructure the DOM so that the new first row would become the first row in the DOM
- [web] Radio-button tabs lack tab, tablist and tabpanel roles (fails WCAG 4.1.2) and
  risk 3.2.2 On Input. ^f5
  > This does not use any ARIA tab widget roles (`tab`, `tablist`, `tabpanel`), meaning it is not exposed as a tab widget to screen reader users.
- [web] Radio state machines lose focus on activation, need arrow keys without saying
  so, and lack fieldset and legend; radios are form controls, not state stores. ^f6
  > don’t use radio controls to track or manage state. They are form controls.
- [web] Arrow-key widgets need script. ^f7
  > In short, if you want arrow key support for a widget then use script.
- [web] Checkbox toggles are fine when the change applies on form submit; his own
  theme toggle falls back to links with a query string without JS. ^f8
  > Though maybe save it for when you plan to progressively enhance the control and/or flipping the toggle will only take effect when the user submits it.
  > If JavaScript is not available, it uses links with a query string which spares the user having to also press a submit button.
- [web] Animated details without JS: wait for interpolate-size beyond Chromium; until
  then script may be better. ^f9
  > until `interpolate-size` is supported by more than Chromium
- [web] Do not use details and summary for site navigation: find in page expands
  them on a match. ^f10
  > since a find-in-page (Ctrl+F) will expand them with a match
- [web] His bottom line: any claim that a CSS-only interactive widget is accessible is
  probably wrong; verify it yourself. ^f11
  > Any person, post, article, tweet, expert, fortune cookie, company, etc., that claims its CSS-only interactive widget is accessible
- [web] (inferred) For meiolol: filters and toggles that apply via form GET submission
  or plain links (state in the URL) avoid every failure listed; :has()-driven
  in-page state does not. ^f12

## Read

- Whole post including 2023 to 2026 updates

## Not read

- Linked posts: sortable table columns (2021), details/summary are not
  [insert control here] (2019), under-engineered toggles
