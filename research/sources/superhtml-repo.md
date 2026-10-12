---
title: 'SuperHTML (kristoff-it/superhtml): README, template and HTML parser source'
url: https://github.com/kristoff-it/superhtml
kind: project
commit: f0deee80ae422938d5cdc43a5598c417670db38b
for: [zig-html-templates]
looked: 2026-10-12
depth: code (README, src/Ast.zig, src/template.zig, src/root.zig, src/example.zig, src/html/ parts)
relevance: high
grade: B/strong
description: HTML validator, formatter, LSP and HTML-valid templating library in Zig by Loris Cro; templates are parsed and checked at run time, values via Scripty
---
# SuperHTML (kristoff-it/superhtml): README, template and HTML parser source

Why: what does SuperHTML check in HTML and templates, how does it escape, and could
meiolol use it as a library or copy its rules into a comptime-checked layer?

## Assessment

- Evidence: B. Created 2024-06, pushed 2026-09-26, 1390 stars, 76 forks, 30
  contributors, release v0.7.0 (2026-06). Used by Zine, packaged in Helix, Homebrew,
  AUR. Author is Zig Software Foundation VP of community. Tokenizer follows the WHATWG
  spec state by state; fuzzed with AFL (src/fuzz/).
- Reasoning: strong. README FAQ explains where it departs from the spec and why.
- Interests: author's own project, promotes Zine.
- Weigh: trust the HTML checks list; the templating API is admitted unpolished and
  tracks Zig master (0.17-dev), so not a dependency for a Zig 0.16 project.

## Findings

- [web/template] [toolchain] Needs Zig 0.17-dev (build.zig.zon); README still says it
  tracks 0.15.1, so the README lags. Not buildable as is with Zig 0.16. `build.zig.zon`,
  `README.md` ^f1
  > .minimum_zig_version = "0.17.0-dev.2319+7cef4755c",
  > SuperHTML tracks the latest Zig release (0.15.1 at the moment of writing).
- [web/template] The templating library API is admittedly unpolished and will change;
  it needs a Scripty VM set up by the host. `README.md` ^f2
  > Note that the API is not polished yet and will change over time.
- [web/template] Templates are parsed at run time from a source string with an
  allocator, in two passes: an HTML AST, then a template AST over it; both return error
  lists rather than failing. Nothing is checked at Zig compile time. `src/example.zig`,
  `src/html/Ast.zig` ^f3
  > const layout_html_ast: superhtml.html.Ast = try .init(arena, layout_src, .superhtml, false);
  > const layout_super_ast: superhtml.Ast = try .init(arena, layout_html_ast, layout_src);
- [web/template] Data reaches templates as a host-defined tagged union `Value` (string,
  int, bool, optional, iterator...); structs opt in to field access with `Dot` and
  expose methods via a `Builtins` namespace. Typing is dynamic: a wrong field is a
  runtime eval error. `src/example.zig` ^f4
  > A SuperHTML VM is created by giving it a Value union that defines
  > the Scripty evaluation context that is made available to SuperHTML
- [web/template] [web] One escape function for both text and attribute values:
  `HtmlSafe` replaces & < > ' " with entities. No URL, JS or CSS contexts. `src/root.zig` ^f5
  > '&' => try out_stream.writeAll("&amp;"),
  > '\'' => try out_stream.writeAll("&apos;"),
- [web/template] `:text` output is escaped with HtmlSafe, `:html` is written raw; both
  accept only string or int, other types are unreachable after checks. `src/template.zig` ^f6
  > writer.print("{f}", .{
  > HtmlSafe{ .bytes = s.value },
- [web/template] Scripted attribute values are always re-emitted double-quoted and
  escaped, whatever quoting the template used. `src/template.zig` ^f7
  > writer.print("=\"{d}\"", .{
- [web/template] Only five special attributes drive logic: `:if`, `:loop`, `:else`,
  `:text`, `:html`; a normal attribute is scripted when its value starts with `$`.
  `src/Ast.zig` ^f8
  > pub const SpecialAttr = enum {
  > if (std.mem.startsWith(u8, code, "$")) {
- [web/template] Template-level checks are structural: `:text` and `:html` mutually
  exclusive and need an empty element, one `:if` or `:loop` per element, `:else` first
  and valueless, blocks need a static id, `<super>` parent needs an id, duplicate
  blocks, Scripty syntax errors. `src/Ast.zig` ^f9
  > text_and_html_are_mutually_exclusive,
  > text_and_html_require_an_empty_element,
  > one_branching_attribute_per_element,
- [web/template] An element with a static id directly inside a `:loop` is an error,
  because it guarantees duplicate ids; an `:if` in between silences it. `src/Ast.zig` ^f10
  > element with an unscripted id cannot be directly under
  > a loop, as that guarantees that duplicated ids will be
- [web] HTML checks go beyond balance: missing or erroneous end tags, void end tags,
  self-closing non-void elements, duplicate attributes and ids, invalid nesting by
  content model, missing required attributes, invalid attribute values per element.
  `src/html/Ast.zig` ^f11
  > .missing_end_tag => w.print("missing end tag", .{}),
  > .void_end_tag => w.print("void elements have no end tag", .{}),
  > .html_elements_cant_self_close => w.print(
- [web] Nesting is checked per element against HTML content-model categories (flow,
  phrasing, interactive), one Zig file per element under src/html/elements/.
  `src/html/Element.zig` ^f12
  > /// The static model of this element. Static means the combination of
  > /// categories and content model that the element has without any change
- [web] Unquoted attribute values are accepted (spec tokenizer); only characters the
  spec forbids in them are errors. Quoting is not enforced. `src/html/Tokenizer.zig` ^f13
  > unexpected_character_in_unquoted_attribute_value,
- [web] Deliberately stricter than the spec: no implicit end tags (e.g. `<li>`), no
  self-closing slash, because in hand-written HTML they hide typos. `README.md` ^f14
  > SuperHTML does not allow closing tags implicitly even if the
  > HTML spec allows it.
  > Because self-closing tags don't exist in HTML
- [web] Checked, not there: full validation does not work on Jinja-style templated
  HTML; other template languages must use `--syntax-only`. `README.md` ^f15
  > Templated HTML (Jinja2, Angular, Mustache, ...) is not yet supported when all validation rules are enabled
- [web/template] (inferred) For a comptime layer, its HTML parser cannot be reused at
  comptime as is: `init` takes an allocator and returns `error{OutOfMemory}`, and the
  tokenizer alone is about 5500 lines. Its check list is the thing to copy. ^f16

## Read

- `README.md`: all
- `src/example.zig`: first 200 lines (VM setup, Value union)
- `src/root.zig`: HtmlSafe
- `src/Ast.zig`: error kinds, attribute parsing, id_under_loop, validateScripty
- `src/template.zig`: `:text`/`:html` output, attribute output, evalAttr
- `src/html/Ast.zig`: Kind, Error tags and messages, init signature
- `src/html/Element.zig`: struct header
- `src/html/Tokenizer.zig`: TokenError list, unquoted value state

## Not read

- `src/html/elements/*.zig`: per-element rules, if we want a list to copy
- `src/html/Attribute.zig`: attribute value validation (3974 lines)
- `src/cli/`, `src/fuzz/`, LSP and formatter
