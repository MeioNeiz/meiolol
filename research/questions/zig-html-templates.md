---
status: decided
priority: now
area: ui
tags: [web, web/template]
parent: zig-web-ui
description: Syntax, escaping, composition and checks for our own small Zig HTML layer, shared by the static site and wasm
decision: src/site/tpl.zig
---
# How should meiolol's own Zig HTML template and component layer look?

Feeds: src/site template layer (replacing positional `w.print` HTML); later the
components compiled to wasm for your.js, learn.js, filters.js (zig-web-ui C7)

## Answer

Write our own; nothing in Zig fits. Zine, SuperHTML and Scripty need Zig 0.17-dev and
parse templates at run time over a dynamic value type, so a wrong field shows up only
when the page renders (C1, C2). The comptime-checked prior art is in Rust and Go:
askama checks hole names against a struct at compile time (C3), maud and templ make
components plain functions with children passed in (C9).

What to copy, in order of how much it would have cost to learn late:

- **Escape by the hole's position, not the value's type.** maud's two open
  break-out bugs (a component's HTML or script JSON spliced into an attribute) both
  come from escaping by type alone; askama and maud have no context-aware escaping
  and call it the missing piece; templ picks the escape from the attribute name
  written in the template and sanitises URL attributes (C4, C5, C6). A comptime
  template knows every hole's position, so this is cheap for us.
- **Script and style bodies are their own context**; data for JS goes in
  `<script type="application/json">` with `<` `>` `&` as `\u` escapes (C7).
- **Trusted HTML is a separate type with an awkward name**; maud's owner regrets how
  easy `PreEscaped` made it (C8).
- **Start strict.** Every engine moved towards more compile-time errors over the
  years, never fewer (C10). SuperHTML's checks are the list to borrow from: balanced
  and void tags, no self-closed non-void elements, duplicate attributes; it rejects
  implicit end tags to catch typos (C11). Full content-model nesting is too much (C12).
- **Valid-HTML templates (Zine's case)** let tools check output structurally, which
  text templates can't (C13). We get most of that by parsing the template string
  at comptime instead of changing its syntax (C14).

Built as src/site/tpl.zig (C14): `{name}` holes checked against the args struct both
ways, escaping by position (text, attribute, URL attribute, inside a tag, script),
`trusted`, `json`, `attr`, `flag`, components as `render(self, w)` values, `t`, `call`,
`each`, comptime tag-balance and SuperHTML-style checks, no allocator. The layout
(html.zig head/foot) and the lane chart moved to it with all 248 fixture site files
byte-identical; the same code compiles to wasm (8.7 KB probe with float formatting).

## Claims

- C1: SuperHTML, Zine and Scripty need Zig 0.17-dev and SuperHTML's library API is admittedly unpolished, so none is usable from our 0.16 build. for: [[superhtml-repo#^f1]], [[superhtml-repo#^f2]], [[zine-repo#^f1]], [[scripty-repo#^f1]]
- C2: Zig's own template prior art parses templates at run time over a dynamic value union, so field mistakes are run-time errors. for: [[superhtml-repo#^f3]], [[superhtml-repo#^f4]], [[scripty-repo#^f3]]
- C3: askama checks hole names against the context struct's fields at compile time. for: [[askama-repo#^f2]], [[askama-repo#^f1]]
- C4: Escaping by value type alone lets a component's HTML or script JSON break out of an attribute; both maud bugs are open and need context-aware escaping. for: [[maud-escaping-issues#^f8]], [[maud-escaping-issues#^f9]]
- C5: askama and maud have no context-aware escaping: every position gets the same HTML escape. for: [[askama-repo#^f7]], [[maud-repo#^f7]]
- C6: templ escapes by the hole's position, decided by the attribute name in the template, and replaces unsafe URL schemes in href/src/action with about:invalid. for: [[templ-repo#^f4]], [[templ-repo#^f5]], [[templ-repo#^f7]]
- C7: Script and style bodies need their own handling; maintainers pass data to JS as `<script type="application/json">` with `<` `>` `&` escaped. for: [[maud-escaping-issues#^f1]], [[maud-escaping-issues#^f5]], [[templ-repo#^f8]], [[maud-repo#^f14]]
- C8: Trusted HTML is a wrapper type in all three engines, and maud's owner regrets making it easy to construct. for: [[maud-repo#^f4]], [[templ-repo#^f12]], [[askama-repo#^f8]], [[maud-escaping-issues#^f7]]
- C9: Components as plain host-language functions, with children passed as an argument, cover layouts without template inheritance. for: [[maud-repo#^f8]], [[templ-repo#^f13]]
- C10: Engines changed over time by adding compile-time errors and escaping inside helpers, not removing them. for: [[askama-repo#^f15]], [[maud-repo#^f10]], [[templ-repo#^f10]]
- C11: SuperHTML checks balanced and void end tags, self-closed non-void elements and duplicate attributes, and rejects implicit end tags because they hide typos. for: [[superhtml-repo#^f11]], [[superhtml-repo#^f14]]
- C12 (inferred): Content-model nesting checks are out of scope for a comptime checker; balance, void and attribute checks give most of the value. from: C11
- C13: Zine's author argues text templates make malformed HTML easy and static checking prohibitive; HTML-as-data templates catch syntax errors. for: [[zine-superhtml-docs#^f1]], [[kristoff-zine-ssg-zig#^f2]]
- C14 (inferred): Parsing the template string at comptime gives position-aware escaping and structural checks without a new syntax or a run-time parser. from: C4, C6, C11, C13
- C15: Mixing host-language control flow into template text keeps causing parse ambiguity in templ; askama keeps control flow in the template. for: [[templ-repo#^f15]], [[askama-repo#^f12]]
- C16 (inferred): Keep control flow in Zig (loops call templates; `each`, `when`) so the template syntax stays holes only. from: C9, C15

## Disagreements

- Where control flow lives: in the template (askama, Zine's `:if`/`:loop`) or in the
  host language (maud, templ). templ's parse ambiguities (C15) and our wish for a tiny
  syntax favour Zig; the cost is that some markup is split across calls.
- Single quotes: maud stopped escaping `'` because its attributes are always
  double-quoted; askama and SuperHTML escape it. We escape it (single-quoted
  attributes are allowed in our templates).

## Open

- Measure the wasm-rendered lane chart against your.js on a phone (zig-web-ui Open)
- Whether to check required attributes (img alt) and duplicate ids, as SuperHTML does
- Fuzzing: put a hostile string in each context, parse the output with a real HTML
  parser and check the structure didn't change ([[maud-escaping-issues#^f6]])
- Leads queued by the reader: Go html/template, google/safehtml, maud PR #460
