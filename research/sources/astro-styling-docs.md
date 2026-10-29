---
title: 'Astro docs: Styles and CSS (scoping, cascading order, bundle control)'
url: https://raw.githubusercontent.com/withastro/docs/main/src/content/docs/en/guides/styling.mdx
kind: docs
commit: 
for: [css-per-page]
looked: 2026-10-29
depth: docs (Styling in Astro, Cascading Order, Frameworks, Production)
relevance: high
grade: A/fair
description: Astro's per-component scoped styles, a per-page CSS chunk plus shared chunks for CSS used by several pages, and inlining of chunks under 4 KB by default
---
# Astro docs: Styles and CSS (scoping, cascading order, bundle control)

Why: Astro is the closest JS framework to our setup (server-rendered components with
scoped styles, islands).

## Assessment

- Evidence: A. Official docs.
- Reasoning: fair. Explains the request-versus-cache balance in a sentence.
- Interests: none.
- Weigh: island CSS handling is not described here.

## Findings

- [web/template] Component `<style>` is scoped by default via a per-component attribute,
  like our `.c-name` scope class. ^f1
  > Astro `<style>` CSS rules are automatically **scoped by default**.
- [web] Build output: one chunk per page plus chunks for CSS shared by several pages, for
  reuse; nothing declared per page. ^f2
  > Each page on your site gets its own chunk, and additionally, CSS that is shared between multiple pages is further split off into their own chunks for reuse.
- [web] Default: chunks over 4 KB are linked, smaller ones inlined, to balance requests
  against cacheable CSS. ^f3
  > by default Astro will link only those in your HTML above 4kB in size as `<link rel="stylesheet">` tags, while inlining smaller ones into `<style type="text/css">`.
  > This approach provides a balance between the number of additional requests and the volume of CSS that can be cached between pages.
- [web] Fixed cascade layering by source: links, then imported sheets, then scoped styles
  last. ^f4
  > **`<link>` tags in the head** (lowest precedence)
  > **scoped styles** (highest precedence)
- [web] Imported CSS joins a page via the import graph, even if the component is never
  rendered. ^f5
  > Importing a component applies any CSS it imports, even if the component is never used:
- [web] Developer upkeep: import the global layout first so it has lowest precedence. ^f6
  > Be sure to import the Layout component before other imports so that it has the lowest precedence.
- [web/wasm] Checked, not there: how CSS of client-only island components is loaded; the docs
  only say framework components use their own styling patterns. ^f7
  > Be sure to follow the patterns each framework recommends:

## Read

- Styling in Astro, Cascading Order, Frameworks and Libraries, Production

## Not read

- Tailwind, preprocessors, Advanced (?raw, ?url imports)
