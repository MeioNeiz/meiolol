---
title: Phoenix LiveView 1.2 released (colocated CSS)
url: https://www.phoenixframework.org/blog/phoenix-liveview-1-2-released
kind: article
commit:
for: [css-per-page]
looked: 2026-10-29
depth: listed (colocated CSS sections read closely)
relevance: medium
grade: A/strong
description: Release post by Steffen Deusch (June 2026) explaining colocated CSS, the @scope approach and why scoping is not shipped by default
---
# Phoenix LiveView 1.2 released (colocated CSS)

Why: the maintainers' reasons for how colocated CSS works.

## Assessment

- Evidence: A. Official release post by a core maintainer.
- Reasoning: strong. Explains the mechanism, a compile pipeline change it forced, and why
  scoping is left out.
- Interests: none known.
- Weigh: trust.

## Findings

- [web/template] Colocated CSS is extracted at compile time into a build folder and processed by the normal CSS pipeline. ^f1
  > the `:type` attribute tells LiveView to extract the content of the tag at compile time into a special `phoenix-colocated` folder in your `_build` directory.
- [web/template] The hard part is scoping, so styles don't hit other components' elements. ^f2
  > What you usually want when defining colocated styles is to scope them, such that they don’t accidentally apply to other elements on the page from different components.
- [web/template] Scope limit: every template's outermost elements get a `phx-r` attribute, slot content included, so a component's rules stop at children from other templates. ^f3
  > We use a special `phx-r` attribute which is added to all outermost elements of a template and which can be used as the limit selector in a `@scope` rule.
- [web/template] They do not ship scoping by default because `@scope` browser support was not good enough in June 2026; users implement a behaviour instead. ^f4
  > The reason is that the `@scope` rule is not yet well supported across browsers at the time of writing (June 2026).
- [web/template] Checked, not there: no per-page or per-LiveView CSS splitting, and no sizes. ^f5
