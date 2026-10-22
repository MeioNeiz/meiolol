---
title: 'SuperHTML (kristoff-it/superhtml): README, template and HTML parser source'
url: https://github.com/kristoff-it/superhtml
kind: project
commit: f0deee80ae422938d5cdc43a5598c417670db38b
for: [zig-html-templates, zig-good-practice, zig-errors-safety, zig-testing, zig-build, zig-style]
looked: 2026-10-12
depth: code (README, src/Ast.zig, src/template.zig, src/root.zig, src/example.zig, src/html/ parts; 2026-10-22 for Zig practice: main.zig, cli/logging.zig, fuzz.zig, errors.zig, build.zig)
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

- [zig/errors] [zig/api] (2026-10-22, Zig practice pass) A `Fatal` error set means
  "already reported to the user": the reporter writes the diagnostic, then returns
  `error.Fatal`, so callers only propagate; OOM is composed in with `||`. `src/errors.zig` ^f17
  > /// Used to catch programming errors where a function fails to report
  > pub const FatalOOM = error{OutOfMemory} || Fatal;
- [zig/errors] The CLI's main ends every error chain in one place: subcommand errors go to
  a `fatal` that prints and exits 1; OOM gets its own `oom()` noreturn helper. `src/main.zig` ^f18
  > } catch |err| fatal("unexpected error: {t}\n", .{err});
  > fn oom() noreturn {
- [zig/errors] [zig/safety] A root `pub fn panic` override routes panics and stack traces
  to the log file in LSP mode (stderr belongs to the protocol) and breaks into the debugger
  in Debug. `src/main.zig` ^f19
  > std.log.err("\n{s}\n\n{?f}", .{ msg, trace });
  > if (builtin.mode == .debug) @breakpoint();
- [zig/style] Logging: `std_options.logFn` filters scopes, in Debug by a hard-coded list,
  otherwise by a build option list of enabled scopes checked at comptime with `inline for`;
  43 `std.log.scoped` uses in src/. `src/cli/logging.zig` ^f20
  > } else inline for (build_options.enabled_scopes) |es| {
- [zig/test] [toolchain] Structured fuzzing with the 0.17 `std.testing.fuzz` and
  `std.testing.Smith`: the fuzzer picks ops from an enum to build plausible HTML, then
  checks parse and render do not crash; a companion test replays a base64 case. `src/fuzz.zig` ^f21
  > try std.testing.fuzz({}, struct {
  > const op = smith.value(Op);
  > test "fuzz case" {
- [zig/test] Also AFL fuzzing behind `-Dfuzz`, with the afl_kit dependency imported lazily
  so normal builds never fetch it. `build.zig` ^f22
  > if (!(b.option(bool, "fuzz", "enable fuzzing") orelse false)) {
  > const afl = b.lazyImport(@This(), "afl_kit") orelse return;
- [zig/test] Formatter tests are round trips: input text equals its formatted output via
  `std.testing.expectFmt`, tests inline at the end of Ast.zig (26 there). `src/html/Ast.zig` ^f23
  > try std.testing.expectFmt(case, "{f}", .{ast.formatter(case)});
- [zig/build] build.zig split into `setupXStep` helper functions (test, check, fuzz, CLI,
  wasm); `test` depends on `check` so the CLI must compile before tests run. `build.zig` ^f24
  > const test_step = b.step("test", "Run unit tests");
  > test_step.dependOn(check);
- [zig/safety] Idiom counts in src/ (43k lines): 106 `assert(`, 37 `@panic(`, 19 `catch
  unreachable`, 23 `errdefer`, 8 `anytype`, 5 `inline for`. ^f25

## Read

- `README.md`: all
- `src/example.zig`: first 200 lines (VM setup, Value union)
- `src/root.zig`: HtmlSafe
- `src/Ast.zig`: error kinds, attribute parsing, id_under_loop, validateScripty
- `src/template.zig`: `:text`/`:html` output, attribute output, evalAttr
- `src/html/Ast.zig`: Kind, Error tags and messages, init signature
- `src/html/Element.zig`: struct header
- `src/html/Tokenizer.zig`: TokenError list, unquoted value state
- 2026-10-22: `src/main.zig`, `src/cli/logging.zig`, `src/fuzz.zig`, `src/errors.zig` head, `build.zig` setup functions, Ast.zig tests

## Not read

- `src/html/elements/*.zig`: per-element rules, if we want a list to copy
- `src/html/Attribute.zig`: attribute value validation (3974 lines)
- `src/cli/`, `src/fuzz/`, LSP and formatter
