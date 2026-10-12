---
title: 'maud (lambda-fairy/maud): book, changelog, escaper'
url: https://github.com/lambda-fairy/maud
kind: project
commit: 42f4789bb5e6af1566c307a6cf87c3ec1e3d6583
for: [zig-html-templates]
looked: 2026-10-12
depth: docs (book chapters on splices, escaping, partials, Render, FAQ; CHANGELOG) and code (escape.rs, json.rs, macro entry)
relevance: high
grade: A/fair
description: Rust html! macro DSL: markup written as Rust tokens, compiled to string pushes, splices escaped by default
---
# maud (lambda-fairy/maud): book, changelog, escaper

Why: what does a mature compile-time HTML DSL (markup in the host language's syntax, no
template files) do about holes, escaping, composition and checks, and what changed?

## Assessment

- Evidence: A. Created 2014-12, pushed 2026-05, 2639 stars, 174 forks, 65 contributors,
  v0.27.0 (2025-02), still pre-1.0 after 11 years.
- Reasoning: fair. The FAQ explains a few choices and their costs honestly; most docs are
  how-to. The design debate lives in issues ([[maud-escaping-issues]]).
- Interests: none known.
- Weigh: trust the mechanics; the FAQ admits the allocation choice may be revisited.

## Findings

- [web/template] Markup is written in the macro's own syntax (`p { "Hi, " (name) "!" }`); holes are `(expr)` splices, escaped by default. `docs/content/splices-toggles.md` ^f1
  > Use `(foo)` syntax to insert the value of `foo` at runtime.
  > Any HTML special characters are escaped by default.
- [web/template] Splices work the same in attribute values, classes and ids; braces concatenate pieces in one attribute (for URLs). `docs/content/splices-toggles.md` ^f2
  > To concatenate multiple values within an attribute, wrap the whole thing in braces.
- [web/template] Toggles: `[bool]` shows or hides a class or boolean attribute; `attr=[Option]` omits the attribute on None. `docs/content/splices-toggles.md` ^f3
  > These are only rendered if the value is `Some<T>`, and entirely omitted if the value is `None`.
- [web/template] Trusted HTML is the `PreEscaped` wrapper type; `Markup` (what `html!` returns) is `PreEscaped<String>`, so a component's output splices into another without double escaping. `maud_macros/src/lib.rs` ^f4
  > maud::PreEscaped(#output_ident)
  > Wrap the string in `(PreEscaped())` to disable this escaping.
- [web/template] Anything spliced goes through the `Render` trait; a type can override `render_to` to write into the buffer directly and must then escape itself. `docs/content/render-trait.md` ^f5
  > To avoid extra allocation, we override the `.render_to()` method instead of `.render()`.
  > This doesn't do any escaping by default, so we wrap the output in an `Escaper` as well.
- [web/template] The escaper replaces four characters, `& < > "`; single quotes stopped being escaped in 0.13 (attributes are always double-quoted). `maud/src/escape.rs` ^f6
  > b'"' => output.push_str("&quot;"),
  > Single quotes (`'`) are no longer escaped
- [web/template] Checked, not there: no context-aware escaping. Attribute, URL, script and style positions all get the same escape; the FAQ calls it very important and still unimplemented. `docs/content/faq.md` ^f7
  > I agree that context-aware escaping is very important, especially for the kind of small-scale development that Maud is used for.
  > But it's a complex feature, with security implications, so I want to take the time to get it right.
- [web/template] Composition: no partials or slots concept; components are plain functions returning `Markup`, and children are passed as a `Markup` argument. `docs/content/partials.md` ^f8
  > Maud does not have a built-in concept of partials or sub-templates.
  > Instead, you can compose your markup with any function that returns `Markup`.
- [web/template] Control flow is host-language flavoured inside the DSL: `@if`, `@if let`, `@for`, `@while`, `@match`, `@let`, mirroring Rust. `docs/content/control-structures.md` ^f9
  > Use `@if` and `@else` to branch on a boolean expression.
- [web/template] Structural errors are compile errors: tags are balanced by braces by construction, and later versions added checks for duplicate attributes and `/` in void elements. `CHANGELOG.md` ^f10
  > Disallow elements that mention the same attribute twice
  > Disallow slashes (`/`) in void elements
- [web/template] Buffer size hint is a heuristic: the template's own token length, used as the output String's capacity. `maud_macros/src/lib.rs` ^f11
  > // Heuristic: the size of the resulting markup tends to correlate with the
  > let mut #output_ident = alloc::string::String::with_capacity(#size_hint);
- [web/template] Regret, open: `html!` returned a writer-taking API until 0.11, then switched to always allocating a String for ergonomics; the FAQ says it may revisit before 1.0. `docs/content/faq.md` ^f12
  > These reasons are why I changed `html!` to return a `String` in version 0.11.
  > So this decision could be revisited prior to the 1.0 release.
- [web/template] Changed: removed the blanket `Render` for every `Display` type (0.24), then brought `Display` back via specialisation (0.25): which values may be spliced was hard to settle. `CHANGELOG.md` ^f13
  > Remove blanket `Render` impl for `T: Display`
  > Render with `Display` using autoref specialization
- [web/template] JSON for scripts (unreleased): a `Json` wrapper replaces `<`, `>`, `&` inside JSON strings with Unicode escapes (backslash u003c and so on), so it is inert in a `<script>` body and still valid JSON. `maud/src/json.rs` ^f14
  > Instead, this module replaces `<`, `>`, and `&` characters in JSON strings
  > This is understood by JSON parsers but is inert as

## Read

- `docs/content/`: splices-toggles, text-escaping, partials, render-trait, faq,
  control-structures (first section)
- `CHANGELOG.md`: all
- `maud/src/escape.rs`, `maud/src/json.rs` (module doc), `maud_macros/src/lib.rs` (expand)

## Not read

- `maud_macros/src/generate.rs`: how literal runs are merged into one push_str
- `docs/content/elements-attributes.md`, `web-frameworks.md`
