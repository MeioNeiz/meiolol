---
title: 'StyleX: A Styling Library for CSS at Scale (Meta, 2025)'
url: https://engineering.fb.com/2025/11/11/web/stylex-a-styling-library-for-css-at-scale/
kind: article
commit:
for: [css-per-page]
looked: 2026-10-29
depth: listed
relevance: medium
grade: A/fair
description: Meta engineering post on StyleX's history (cx CSS modules, runtime CSS-in-JS) and compiler; atomic classes cut CSS by 80 percent
---
# StyleX: A Styling Library for CSS at Scale (Meta, 2025)

Why: Meta's own account of what failed before StyleX (per-component CSS files, runtime
injection).

## Assessment

- Evidence: A. Meta's StyleX team; StyleX runs Facebook, Instagram, WhatsApp, Messenger,
  Threads.
- Reasoning: fair. History and mechanism; repeats the 80 percent figure without new data.
- Interests: promoting their open source tool.
- Weigh: the 80 percent is the same measurement as [[fb-redesign-2020]].

## Findings

- [web] Before: CSS at Meta's scale meant collisions across bundles, dependencies between sheets, specificity wars, and hundreds of KB of unused rules per page. ^f1
  > Serving CSS at such a scale resulted in collisions across bundles, difficulties in managing dependencies between stylesheets, and challenges in reconciling competing rules that frequently led to specificity wars.
  > Large, monolithic CSS bundles meant browsers were downloading hundreds of kilobytes of unused rules on every page load, slowing rendering and interaction.
- [web] cx, a CSS-modules-like per-component system, fixed collisions and dependencies but was limited to static CSS files. ^f2
  > cx resolved issues with namespace collisions and dependency management but remained limited to static styles defined in separate files.
- [web] Runtime CSS-in-JS (style tags generated during render) was rejected for measurable overhead. ^f3
  > But early CSS-in-JS systems relied on runtime injection: dynamically generating <style> tags and mutating the DOM during render, patterns that introduced measurable performance overhead.
- [web] The compiler walks all files, makes one class per declaration, dedupes shared declarations and emits one sorted static sheet; size plateaus. ^f4
  > Finally, the CSS rules are sorted and outputted into a static sheet.
  > Styles are converted to classes containing a single style declaration for reuse across a codebase so CSS size plateaus as the application grows.
- [web] Number: atomic classes reduced CSS size by 80 percent. ^f5
  > Atomic classes reduced CSS size by 80% and made styling maintainable across a rapidly scaling codebase.
- [web] Order is enforced by a numeric priority per rule (shorthand before longhand, hover before active, media last) applied through `@layer` or a polyfill. ^f6
  > we compute a numerical priority alongside each CSS rule. We use these priorities alongside a user-configured styleResolution to determine the specificity of each class selector using the @layer at-rule or equivalent polyfill.
