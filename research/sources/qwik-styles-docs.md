---
title: 'Qwik docs: Styles (useStyles$, useStylesScoped$)'
url: https://raw.githubusercontent.com/QwikDev/qwik/main/packages/docs/src/routes/docs/(qwik)/core/styles/index.mdx
kind: docs
commit: 
for: [css-per-page]
looked: 2026-10-29
depth: docs (useStylesScoped$, useStyles$, why not inline style tags)
relevance: medium
grade: B/fair
description: Qwik components register their CSS with useStyles$; SSR puts styles of rendered components in head once, client-first renders load and insert them lazily
---
# Qwik docs: Styles (useStyles$, useStylesScoped$)

Why: a resumable framework where components render on server or client, like our islands.

## Assessment

- Evidence: B. Official docs of a smaller framework.
- Reasoning: fair. Explains the double-load problem and the two render cases.
- Interests: none.
- Weigh: per-component registration is explicit (a hook call), but per-page selection is
  automatic from what rendered.

## Findings

- [web] [web/wasm] Each component registers its CSS with `useStyles$`, a lazy reference,
  so it loads only when needed and not twice on hydration. ^f1
  > Component styles allow Qwik to lazy load the style information for the component only when needed, which avoids double loading during SSR hydration.
- [web] Inline `<style>` inside a component's output loads twice: in SSR HTML and again on
  re-render. ^f2
  > The problem with this approach is that we will load styles twice.
- [web] Server-rendered components get styles in head during SSR; more instances need no
  more CSS. ^f3
  > The component is rendered on the server and the styles are inserted into `<head>` as part of the SSR.
- [web/wasm] A component first rendered on the client has no head styles yet, so they are
  loaded and inserted then. ^f4
  > Adding a new component that was not part of SSR requires that styles are loaded and inserted into `<head>`.
- [web/template] Scoped variant marks selectors with a unique name to avoid clashes. ^f5
  > uses an emoji to set a unique name on the selector, to avoid CSS name / selector clashes

## Read

- useStylesScoped$, useStyles$, the why section

## Not read

- CSS modules, styled-components, vanilla-extract sections
