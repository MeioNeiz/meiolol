---
title: 'web-features 3.44.0: Baseline data for no-script UI features'
url: https://www.npmjs.com/package/web-features
kind: dataset
commit: 
for: [zig-only-frontend]
looked: 2026-10-22
depth: docs (data.json, 21 features extracted)
relevance: high
grade: A/fair
description: The W3C WebDX group's web-features package (npm 3.44.0, 22 Oct 2026), the data behind Baseline badges on MDN, caniuse and web.dev; extract for popover, dialog, invokers, details, select, anchor, :has, view transitions, scroll timelines, search, container queries, field-sizing, :user-invalid
---
# web-features 3.44.0: Baseline data for no-script UI features

Why: as of October 2026, which HTML and CSS replacements for JS are Baseline, and
which still miss Safari or iOS (players are on phones)?

## Assessment

- Evidence: A. Canonical Baseline source (W3C WebDX community group), built on
  browser-compat-data; 1231 features in this release. Raw file is our extract of
  data.json (feature line plus every compat key not Baseline high), copied verbatim.
- Reasoning: fair. Data, no reasons. A feature is Baseline only when every listed
  compat key is in all core browsers, so one late sub-key holds back a whole feature.
- Interests: none (browser vendors jointly).
- Weigh: trust dates and versions; read per-key status before calling a feature
  unusable (anchor positioning core is in everywhere, only two newer keys are not).
  "low" is newly available; widely available is 30 months later.

## Findings

- [web] Popover: newly available since 27 Jan 2025; iOS Safari only from 18.3. `popover` ^f1
  > baseline: low; baseline_low_date: 2025-01-27; baseline_high_date: None
  > support: chrome 116, chrome_android 116, edge 116, firefox 125, firefox_android 125, safari 17, safari_ios 18.3
- [web] popover="hint" is not Baseline: Chrome 151 and Firefox 153, no Safari. `popover-hint` ^f2
  > support: chrome 151, chrome_android 151, edge 151, firefox 153, firefox_android 153
- [web] `<dialog>` is widely available (since Sept 2024); `closedby` (light dismiss for
  dialogs) has no Safari. `dialog`, `dialog-closedby` ^f3
  > baseline: high; baseline_low_date: 2022-03-14; baseline_high_date: 2024-09-14
  > support: chrome 134, chrome_android 134, edge 134, firefox 141, firefox_android 141
- [web] Invoker commands (command, commandfor): newly available since 12 Dec 2025,
  Safari and iOS 26.2. `invoker-commands` ^f4
  > baseline: low; baseline_low_date: 2025-12-12; baseline_high_date: None
- [web] Interest invokers (hover or focus to show): Chromium only, from 142; no
  Firefox, no Safari. `interest-invokers` ^f5
  > support: chrome 142, chrome_android 142, edge 142
- [web] Exclusive accordions (`<details name>`): newly available since 3 Sept 2024,
  Safari 17.2; `::details-content` styling since Sept 2025 (Safari 18.4). `details-name`, `details-content` ^f6
  > baseline: low; baseline_low_date: 2024-09-03; baseline_high_date: None
  > baseline: low; baseline_low_date: 2025-09-16; baseline_high_date: None
- [web] Customizable `<select>`: not Baseline; Chromium 135 and Safari 27, no
  Firefox. `customizable-select` ^f7
  > support: chrome 135, chrome_android 135, edge 135, safari 27, safari_ios 27
- [web] Anchor positioning core properties (anchor-name, position-area,
  position-try-fallbacks) are newly available since 13 Jan 2026 (Firefox 147, Safari
  26); the feature as a whole is not Baseline only because the renamed
  position-visibility values anchor-valid and anchor-visible are Safari 27 only. `anchor-positioning` ^f8
  > compat key css.properties.anchor-name: baseline low, low date 2026-01-13; support: chrome 125, chrome_android 125, edge 125, firefox 147, firefox_android 147, safari 26, safari_ios 26
  > compat key css.properties.position-visibility.anchor-valid: baseline False, low date None; support: safari 27, safari_ios 27
- [web] :has() became widely available on 19 June 2026 (Safari 15.4, Firefox 121). `has` ^f9
  > baseline: high; baseline_low_date: 2023-12-19; baseline_high_date: 2026-06-19
- [web] Same-document view transitions are newly available (Oct 2025, Firefox 144);
  cross-document ones (`@view-transition`) are not: Chromium 126 and Safari 18.2, no
  Firefox. `view-transitions`, `cross-document-view-transitions` ^f10
  > baseline: low; baseline_low_date: 2025-10-14; baseline_high_date: None
  > support: chrome 126, chrome_android 126, edge 126, safari 18.2, safari_ios 18.2
- [web] Scroll-driven animations: not Baseline; Chromium 115 and Safari 26, no Firefox. `scroll-driven-animations` ^f11
  > compat key css.properties.animation-timeline: baseline False, low date None; support: chrome 115, chrome_android 115, edge 115, safari 26, safari_ios 26
- [web] `<search>` widely available since 13 Apr 2026; size container queries widely
  available since 14 Aug 2025. `search`, `container-queries` ^f12
  > baseline: high; baseline_low_date: 2023-10-13; baseline_high_date: 2026-04-13
  > baseline: high; baseline_low_date: 2023-02-14; baseline_high_date: 2025-08-14
- [web] field-sizing: newly available since 16 June 2026 (Firefox 152 last, Safari 26.2). `field-sizing` ^f13
  > baseline: low; baseline_low_date: 2026-06-16; baseline_high_date: None
- [web] :user-valid and :user-invalid widely available since 2 May 2026. `user-pseudos` ^f14
  > baseline: high; baseline_low_date: 2023-11-02; baseline_high_date: 2026-05-02
- [web] Safari 27 counts as released by mid September 2026: position-anchor became
  Baseline on 14 Sept 2026 with Safari 27. `anchor-positioning` ^f15
  > compat key css.properties.position-anchor: baseline low, low date 2026-09-14; support: chrome 151, chrome_android 151, edge 151, firefox 151, firefox_android 151, safari 27, safari_ios 27

- [web] (inferred) Every feature here not yet Baseline is an enhancement where
  missing support degrades gracefully (no animation, default select styling, no hover
  card) except interest invokers, which leave the content unreachable in Safari and
  Firefox unless a click path also exists. ^f16

- [web] CSS scroll markers (`::scroll-marker`, the CSS carousel and tabs feature)
  are Chromium only, from 135. `scroll-markers` ^f17
  > description: A scroll marker scrolls a container to a scroll target.
  > support: chrome 135, chrome_android 135, edge 135
- [web] Animating details open and closed: `interpolate-size` (height to auto) is
  Chromium only; `@starting-style` (entry transitions for popovers and dialogs) is
  newly available since Aug 2024, Safari 17.5. `interpolate-size`, `starting-style` ^f18
  > support: chrome 129, chrome_android 129, edge 129
  > baseline: low; baseline_low_date: 2024-08-06; baseline_high_date: None

## Read

- data.json: the 18 features in the raw extract, every compat key not Baseline high

## Not read

- Other features (e.g. `scroll-state` container queries, `@starting-style`,
  `interpolate-size`) that could matter for no-script disclosure animations
