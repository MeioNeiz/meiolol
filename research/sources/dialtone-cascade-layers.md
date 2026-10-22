---
title: 'Dialpad Dialtone design system: CSS Cascade Layers migration guide'
url: https://dialtone.dialpad.com/guides/migration/css-cascade-layers/
kind: docs
commit: 
for: [ui-tooling]
looked: 2026-10-22
depth: docs (to no-layers build)
relevance: medium
grade: B/strong
description: A production design system's move to @layer reset, base, components, utilities: why (specificity wars, !important), and the gotchas (unlayered CSS wins, !important order reverses)
---
# Dialpad Dialtone design system: CSS Cascade Layers migration guide

Why: what @layer buys a real design system, and what bit them.

## Assessment

- Evidence: B. Dialpad's production design system; one company's migration.
- Reasoning: strong. Explains mechanism, costs and the breaking cases.
- Interests: none.
- Weigh: the gotchas are spec behaviour, so they apply to meiolol's planned layers too.

## Findings

- [web/qa] Four layers: reset, base (tokens, fonts, themes), components, utilities.
  What changed ^f1
  > @layer dialtone.reset, dialtone.base, dialtone.components, dialtone.utilities;
- [web/qa] Before layers, utilities beating components needed !important, specificity
  care and load order. Before ^f2
  > Adding `!important` to every utility
- [web/qa] Layer order beats specificity; specificity still applies within a layer.
  After, Recommended migration ^f3
  > **No specificity hacks needed.** Layer priority beats specificity.
- [web/qa] Gotcha: any unlayered CSS beats every layer, whatever its specificity. What
  breaks ^f4
  > **any unlayered CSS in your app automatically wins over Dialtone** — regardless of specificity or source order.
- [web/qa] Gotcha: !important reverses layer order. With !important ^f5
  > ### With `!important` (Order Reverses!)
- [web/qa] Contributors must put every new style in a named layer. For Contributors ^f6
  > **For Contributors**: All new styles must be wrapped in the appropriate `@layer` block.
- [web/qa] (inferred) For meiolol's comptime-concatenated CSS: a Zig lint that every rule
  sits inside one of the declared layers, and no !important, closes both gotchas. ^f7

## Read

- Migration guide to the no-layers build

## Not read

- Contributor guide /guides/css-layers/
