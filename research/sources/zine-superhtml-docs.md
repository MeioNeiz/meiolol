---
title: SuperHTML Basics (Zine docs)
url: https://zine-ssg.io/docs/superhtml/
kind: docs
for: [zig-html-templates]
looked: 2026-10-12
depth: docs (all)
relevance: high
grade: B/strong
description: Official SuperHTML template docs - scripted attributes, :text/:html/:if/:loop, ctx, extend/super layouts, and why templates must be well-formed HTML
---
# SuperHTML Basics (Zine docs)

Why: SuperHTML template syntax, escaping, layouts, and the author's case for
HTML-valid templates.

## Assessment

- Evidence: B. Canonical docs of a two-year-old SSG (Zine, 1607 stars, 30 contributors).
- Reasoning: strong. Argues against curly-brace macros with examples, explains the
  unusual parent-id matching for layouts and what it buys.
- Interests: author's own project.
- Weigh: design rationale is the useful part; the API itself is Zine-specific.

## Findings

- [web/template] The case against curly-brace templates: they preprocess HTML as text,
  so they allow malformed output and stop tooling catching mistakes statically.
  `#intro` ^f1
  > making it easier for humans to output malformed html
  > making it prohibitively complex for tooling to catch mistakes statically (i.e. in your editor)
- [web/template] SuperHTML cannot express a template that closes and reopens tags
  across a branch; it works within well-formed HTML. `#intro` ^f2
  > This example can’t be recreated faithfully in SuperHTML because it operates within the limits of well-formed HTML.
- [web/template] Any attribute can be scripted with a Scripty expression; logic sits in
  attributes, not in text between tags. `#scripting-attrs` ^f3
  > Any HTML attribute can be scripted (with some restrictions explained later in this page).
- [web/template] `:text` escapes, `:html` does not and is marked unsafe for untrusted
  data; both need an empty element and accept String or Int. `#:text`, `#:html` ^f4
  > The value is HTML-escaped before printing.
  > Same as `:text`, but it doesn’t escape HTML. Avoid using it with untrusted data.
- [web/template] `:if` takes a Bool or an optional; a present optional is bound as
  `$if`. `:loop` binds `$loop`, with `$loop.up()` for the outer loop. `#:if`, `#:loop` ^f5
  > When the value is present, it becomes available as the [`$if`](https://zine-ssg.io/docs/superhtml/scripty/) Scripty global variable.
- [web/template] `<ctx>` renders no tags, so it places text without a wrapper element
  and binds local names; shadowing a ctx name is an error. `#ctx` ^f6
  > This element supports all the logic attributes but has the property that its start/end tags will not be rendered.
  > Shadowing is not allowed for `<ctx>` attributes and will be reported as an error
- [web/template] Layouts: a base template marks holes with `<super>` inside an element
  with an id; an extending template starts with `<extend template=...>` and supplies
  top-level elements matching that tag and id. Chains are allowed. `#super` ^f7
  > The super tag defines an extension point in a template. The direct parent of a super tag must have an `id` attribute.
  > **Each top level element in a template that extends another must correspond to a super tag in the template being extended.**
- [web/template] Matching on parent tag plus id, not a named block, is called type
  safety: a block's wrapper element must match the slot's, or the build fails.
  `#why-no-ids` ^f8
  > Repeating the parent element is a form of _**type safety**_ for your templates, in a sense.
  > Both tags and ids must match in order to avoid confusion
- [web/template] Templates are thought of as interfaces: `<super>` defines one,
  extending fulfils it. `#extension-chains` ^f9
  > Define an interface by using `<super>`.

## Read

- All sections

## Not read

- SuperHTML Scripty reference (https://zine-ssg.io/docs/superhtml/scripty/): builtin
  functions list, only if we copied the expression style
