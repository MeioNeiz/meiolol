---
title: 'Lit docs: Styles (static styles, shadow DOM, external sheets)'
url: https://lit.dev/docs/components/styles/
kind: docs
commit:
for: [css-per-page]
looked: 2026-10-29
depth: docs (whole page)
relevance: medium
grade: A/fair
description: Lit web components keep CSS in the component class, applied to each shadow root; external link sheets are discouraged for FOUC
---
# Lit docs: Styles (static styles, shadow DOM, external sheets)

Why: web components are the other way client-rendered components carry their CSS: it
ships with the component's code, so it is there the moment the component renders.

## Assessment

- Evidence: A. Official docs of Lit (Google, since 2017, 21.9k stars).
- Reasoning: fair. Gives reasons for each recommendation (performance, FOUC, polyfill).
- Interests: none known.
- Weigh: trust; mechanism in [[lit-css-tag]].

## Findings

- [web/wasm] Styles live in the component's static `styles` field and are scoped to its shadow root, the recommended and fastest way. ^f1
  > You define scoped styles in the static `styles` class field using the tagged template literal `css` function. Defining styles this way results in the most optimal performance:
- [web/wasm] Static styles are evaluated once per class and shared by all instances. ^f2
  > Static styles apply to all instances of a component. Any expressions in CSS are evaluated **once**, then reused for all instances.
- [web/wasm] A link to an external sheet inside the component is not recommended, partly because it can flash unstyled content while it loads. ^f3
  > External styles can cause a flash-of-unstyled-content (FOUC) while they load.
- [web/wasm] Changing text in a style element makes the browser re-parse the whole element, so per-instance style elements are costly. ^f4
  > When any text inside a `<style>` element changes, the browser must re-parse the whole `<style>` element, resulting in unnecessary work.
- [web/wasm] Shared styles are shared by importing a `css` value into several components' `styles` arrays (module imports decide what CSS a component brings). ^f5
  > import { buttonStyles } from './button-styles.js';class MyElement extends LitElement {  static styles = [    buttonStyles,
- [web/wasm] (inferred) For islands: CSS bundled with the component's code (in JS or wasm) avoids FOUC for client-only views, at the cost of shipping it in the code bundle rather than a cacheable sheet, and only works for shadow-DOM-scoped or runtime-inserted rules. ^f6
