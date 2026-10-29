---
title: Rebuilding our tech stack for the new Facebook.com (2020)
url: https://engineering.fb.com/2020/05/08/web/facebook-redesign/
kind: article
commit:
for: [css-per-page]
looked: 2026-10-29
depth: listed (CSS sections read closely; JS, data, navigation sections skimmed)
relevance: high
grade: A/strong
description: Meta engineers on the 2020 Facebook.com rewrite; old site 400 KB gz CSS with 10 percent used, atomic CSS cut homepage CSS by 80 percent into one shared sheet
---
# Rebuilding our tech stack for the new Facebook.com (2020)

Why: the source of the numbers behind StyleX's "one shared atomic sheet" stance.

## Assessment

- Evidence: A. First-hand report of the Facebook.com rewrite by its engineers, at the
  largest scale there is.
- Reasoning: strong. Explains how the CSS grew, why, and the order bug as well as size.
- Interests: Meta describing its own success; numbers are for the homepage only.
- Weigh: the numbers are real but specific to a huge site; the growth argument transfers,
  the absolute sizes don't.

## Findings

- [web] Old site: over 400 KB compressed (2 MB raw) of CSS on the homepage, of which 10 percent was used for the first render. ^f1
  > On our old site, we were loading more than 400 KB of compressed CSS (2 MB uncompressed) when loading the homepage, but only 10 percent of that was actually used for the initial render.
- [web] Cause: CSS only grew, since every feature added CSS and little was removed. ^f2
  > We didn’t start out with that much CSS; it just grew over time and rarely decreased. This happened in part because every new feature meant adding new CSS.
- [web] Atomic CSS grows with unique declarations, not with features, so they could merge all of it into one small shared sheet: under 20 percent of the old download. ^f3
  > Atomic CSS has a logarithmic growth curve because it’s proportional to the number of unique style declarations rather than to the number of styles and features we write.
  > This lets us combine the generated atomic CSS from across our site into a single, small, shared stylesheet.
  > As a result, the new homepage downloads less than 20 percent of the CSS the old site downloaded.
- [web] Styles are colocated with components so they are deleted together; splitting into bundles happens only at build time. ^f4
  > Now, we colocate our styles with our components so they can be deleted in tandem, and only split them into separate bundles at build time.
- [web] Ordering bug named: precedence depends on order, which automated packaging changes, so one file's change broke another's styles; fixed by a stable order and no descendant selectors. ^f5
  > CSS precedence depends on ordering, which is especially difficult to manage when using automated packaging that can change over time.
  > We guarantee that the styles are applied in a stable order, and we don’t support CSS descendant selectors.
- [web] Themes as CSS variables in one sheet: different pages can have different themes without more CSS. ^f6
  > different pages can have different themes without downloading additional CSS
- [web] Checked: the post says a build tool splits styles into separate bundles, but gives no detail of how or how many; the measured win is attributed to atomic CSS in one shared sheet. ^f7
  > a build tool splits these styles into separate, optimized bundles
