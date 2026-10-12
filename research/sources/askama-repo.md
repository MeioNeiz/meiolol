---
title: 'askama (askama-rs/askama): book and escaper'
url: https://github.com/askama-rs/askama
kind: project
commit: 79632d970fcbae289912dee136ca250fdbf1478e
for: [zig-html-templates]
looked: 2026-10-12
depth: docs (book: introduction, template_syntax, filters, performance, upgrading, configuration) and code (askama/src/html.rs, lib.rs)
relevance: high
grade: A/fair
description: Jinja-like Rust template engine; a derive macro compiles a template file into Rust code over a user struct
---
# askama (askama-rs/askama): book and escaper

Why: what does a mature compile-time-checked, text-template (Jinja) engine do about holes,
escaping, composition and checks, and what did it change?

## Assessment

- Evidence: A. askama since about 2017 (djc/askama), forked as rinja and re-merged into
  askama-rs in 2025; this repo created 2024-06, pushed 2026-10-12, 1227 stars, 100+
  contributors, v0.16.1 (2026-09); docs.rs switched to it (per upgrading.md).
- Reasoning: fair. The book explains what and how, rarely why; upgrading.md is a frank list
  of breaking changes.
- Interests: none known.
- Weigh: trust the mechanics (code read). The book's escaping example is stale (see ^f5),
  so verify behaviour against tests, not prose.

## Findings

- [web/template] Templates are Jinja-syntax files; a derive macro generates Rust code from them at compile time, with a user struct as the context. `book/src/introduction.md` ^f1
  > It generates Rust code from your templates at compile time
  > based on a user-defined `struct` to hold the template's context.
- [web/template] Holes are `{{ expr }}`, escaped and printed; variables are the context struct's fields, so a misspelt name is a Rust compile error in the generated code. `book/src/template_syntax.md` ^f2
  > Top-level template variables are defined by the template's context type.
- [web/template] The checker only sees the struct's fields and template variables, not deeper: `x.y is defined` does not compile. `book/src/template_syntax.md` ^f3
  > Due to proc-macro limitations, askama can only see the fields of your current type and the variables
  > declared in the templates.
- [web/template] Escaping is per template, chosen by file extension (html, htm, xml escape; txt, md and others don't); one escaper per template, not per position in the HTML. `book/src/template_syntax.md` ^f4
  > It infers the escaping context from the extension of template filenames, escaping by default if the extension is one of `html`, `htm`, or `xml`.
- [web/template] The HTML escaper replaces only the five characters `"&'<>`, the same in text and attributes; code checks a byte range and a table. `askama/src/html.rs` ^f5
  > const CHARS: &[u8] = br#""&'<>"#;
  > Askama escapes `<`, `>`, `&`, `"`, and `'`, according to the
- [web/template] The book's example still shows `/` escaped as `&#x2f;`; the test asserts decimal entities and no `/` escaping: the docs lagged a change to the escaper. `testing/tests/filters.rs` ^f6
  > "// my &#60;html&#62; is &#34;unsafe&#34; &#38; \
- [web/template] Checked, not there: no context-aware escaping. Attribute, URL, JS and CSS positions get the same five-character escape; `urlencode` and `json` are explicit filters the author must remember. ^f7
- [web/template] Trusted HTML: `|safe` per expression, or a type marked with the `HtmlSafe` marker trait is never escaped (integers are by default). `book/src/filters.md` ^f8
  > any type that implements that trait won't get automatically
  > escaped in a `{{expr}}` expression.
- [web/template] A filter can return `Safe(...)` to mark its own output trusted, so trust is carried by type rather than by a flag at the call site. `book/src/filters.md` ^f9
  > Then you can also mark the output as safe using `askama::filters::Safe`:
- [web/template] Nesting one template in another escapes the inner HTML unless the inner type is marked `HtmlSafe` or the hole uses `|safe`: composition and escaping collide. `book/src/template_syntax.md` ^f10
  > Note that if your inner template like `SectionOne` renders HTML content, then you may want to
  > disable escaping when injecting it into an outer template, e.g. `{{ s1 | safe }}`.
- [web/template] Composition: Jinja inheritance (`extends`, `block`, `super()`), `include` with a compile-time literal path, and macros; a macro called with `{% call %}` gets its body as `caller()` (a children slot). `book/src/template_syntax.md` ^f11
  > A base template defines **blocks** that child templates can override.
  > The path to include must be a string literal, so that it is known at compile time.
- [web/template] Control flow lives in the template: if, match, for/else, let, break/continue. `book/src/template_syntax.md` ^f12
  > `{% for ... in ... %} ... {% else %} ... {% endfor %}`
- [web/template] Each template gets a compile-time `SIZE_HINT` (estimated output length) used to reserve the buffer once in `render`. `askama/src/lib.rs` ^f13
  > Provides a rough estimate of the expanded length of the rendered template.
  > let _ = buf.try_reserve(Self::SIZE_HINT);
- [web/template] Going through Rust's dynamic `fmt` machinery costs a lot; askama added `FastWritable` to bypass it for custom types. `book/src/performance.md` ^f14
  > On average, expect `.to_string()` to be 100% to 200% slower than `.render()`.
- [web/template] Changed over time: duplicated blocks became a compile error (was a warning); filters that build HTML (`linebreaks`) now escape their input themselves. `book/src/upgrading.md` ^f15
  > Duplicated blocks will now error and prevent compilation instead of emitting a warning.
  > `|linebreaks`, `|linebreaksbr` and `|paragraphbreaks` escape their input automatically.
- [web/template] (inferred) The trend is towards more compile-time errors and escaping as the default inside helpers, never fewer. ^f16

## Read

- `book/src/introduction.md`, `performance.md`, `upgrading.md`: all
- `book/src/template_syntax.md`: overview, variables, inheritance, escaping, include,
  templates in templates, macro call blocks
- `book/src/filters.md`: escape, safe, HTML-safe types
- `askama/src/html.rs`: escaper; `askama/src/lib.rs`: Template trait, SIZE_HINT

## Not read

- `askama_derive/src/generator/`: how SIZE_HINT is estimated, how much code a template emits
- Issue tracker beyond a title search (no context-aware escaping issue found there)
