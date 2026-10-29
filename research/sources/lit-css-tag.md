---
title: 'Lit reactive-element css-tag.ts: adoptedStyleSheets'
url: https://github.com/lit/lit
kind: project
commit: 16507ef656417c9c53a55a02a44a563bbbf2c484
for: [css-per-page]
looked: 2026-10-29
depth: code (packages/reactive-element/src/css-tag.ts)
relevance: medium
grade: A/fair
description: How Lit turns a component's css text into one constructable CSSStyleSheet shared across shadow roots via adoptedStyleSheets, with a style-element fallback
---
# Lit reactive-element css-tag.ts: adoptedStyleSheets

Why: the mechanism behind "component CSS in code" without re-parsing per instance.

## Assessment

- Evidence: A. Lit core (2017, 21.9k stars).
- Reasoning: fair. Doc comments explain the fallback ordering.
- Interests: none known.
- Weigh: trust the code.

## Findings

- [web/wasm] Lit uses constructable sheets when the browser has `adoptedStyleSheets` and `CSSStyleSheet.replace`. `packages/reactive-element/src/css-tag.ts` ^f1
  > 'adoptedStyleSheets' in Document.prototype &&
  > 'replace' in CSSStyleSheet.prototype;
- [web/wasm] Each CSS result builds one `CSSStyleSheet` lazily and caches it by template literal, so the CSS is parsed once and the same sheet object is shared. `packages/reactive-element/src/css-tag.ts` ^f2
  > const cssTagCache = new WeakMap<TemplateStringsArray, CSSStyleSheet>();
  > (this._styleSheet = styleSheet = new CSSStyleSheet()).replaceSync(
- [web/wasm] Applying styles sets the shadow root's `adoptedStyleSheets` to those shared sheets; without support it appends a style element per root. `packages/reactive-element/src/css-tag.ts` ^f3
  > (renderRoot as ShadowRoot).adoptedStyleSheets = styles.map((s) =>
  > const style = document.createElement('style');
- [web/wasm] (inferred) The same API works on `document.adoptedStyleSheets`, so a wasm island could add its components' CSS as one constructed sheet before inserting DOM, with no network fetch and no flash. ^f4
