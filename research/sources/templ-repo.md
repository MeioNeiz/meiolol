---
title: 'templ (a-h/templ): docs, ADR 0001, runtime buffer'
url: https://github.com/a-h/templ
kind: project
commit: 8bbdcac97f59cd4fef43a834a9357b68da243d71
for: [zig-html-templates]
looked: 2026-10-12
depth: docs (syntax: expressions, attributes, statements, composition, scripts, CSS, raw HTML; security; components; generation; ADR 0001) and code (runtime/buffer.go, bufferpool.go)
relevance: high
grade: A/fair
description: Go HTML templating: .templ files compiled by a generator into typed Go functions returning templ.Component; context-aware escaping by attribute kind
---
# templ (a-h/templ): docs, ADR 0001, runtime buffer

Why: templ is the closest match to "typed components compiled to host code"; what does it
do per context (attributes, URLs, JS, CSS), how do components and children work, and what
changed?

## Assessment

- Evidence: A. Created 2021-04, pushed 2026-10-09, 10576 stars, 370 forks, 100+
  contributors, frequent releases (v0.3.1070, 2026-10-04).
- Reasoning: fair. Docs explain the security reason for each special case; ADRs (three)
  record alternatives; some pages lag the code (see ^f10).
- Interests: none known.
- Weigh: trust the mechanics; where security.md and the syntax pages disagree, the syntax
  pages are newer.

## Findings

- [web/template] A `.templ` file is compiled by `templ generate` into Go functions; each component is a typed Go function returning a `templ.Component` with one `Render(ctx, w)` method. `docs/docs/04-core-concepts/01-components.md` ^f1
  > templ Components are markup and code that is compiled into functions that return a `templ.Component` interface by running the `templ generate` command.
- [web/template] Holes are `{ expr }` with Go expressions; only strings, numbers and booleans (and types based on them) may be interpolated, so a struct in a hole is a compile error. `docs/docs/03-syntax-and-usage/04-expressions.md` ^f2
  > The supported types for interpolation are:
- [web/template] A hole may call a function returning `(value, error)`; the error surfaces from `Render` with its source location. `docs/docs/03-syntax-and-usage/04-expressions.md` ^f3
  > If the function returns an error, the `Render` function will return an error containing the location of the error and the underlying error.
- [web/template] Escaping is context-aware: text and attributes are HTML-escaped, and the escape depends on where the hole is. `docs/docs/03-syntax-and-usage/04-expressions.md` ^f4
  > Content is automatically escaped using context-aware HTML encoding rules to protect against XSS and CSS injection attacks.
- [web/template] URL attributes (`href`, `action`, `src`) with a dynamic string are sanitised: unsafe schemes such as `javascript:` become `about:invalid#TemplFailedSanitizationURL`; constants are left alone; `templ.SafeURL` bypasses. `docs/docs/03-syntax-and-usage/03-attributes.md` ^f5
  > When you pass a `string` to these attributes, templ will automatically sanitize the input URL, ensuring that the protocol is safe (e.g., `http`, `https`, or `mailto`) and does not contain potentially harmful protocols like `javascript:`.
  > If a URL is not safe, templ will replace the URL with `about:invalid#TemplFailedSanitizationURL`.
- [web/template] What goes wrong without attribute escaping: a quote in the value closes the attribute and starts a new one such as `onclick`. `docs/docs/03-syntax-and-usage/03-attributes.md` ^f6
  > without escaping, if a string contained `http://google.com" onclick="alert('hello')"`, the browser would interpret this as a URL followed by an `onclick` attribute, which would execute JavaScript code.
- [web/template] Context is decided by the attribute's name written in the template; an attribute whose name is itself an expression loses the special handling. `docs/docs/03-syntax-and-usage/03-attributes.md` ^f7
  > if you use a string expression to set the key of an attribute, it will be treated as a normal string attribute, without type specific escaping.
- [web/template] Data to the client: `templ.JSONString` for an attribute (HTML-escaped JSON), `templ.JSONScript` for a `<script type="application/json">`; the docs prefer these over interpolating into JS. `docs/docs/03-syntax-and-usage/13-script-templates.md` ^f8
  > It's better to pass data to the client in a HTML attribute or a script tag, as this separates the data from the JavaScript code, making it easier to maintain and debug.
- [web/template] Inside `<script>`, `{{ value }}` is escaped by JS position: string literal, outside a string (JSON), template literal (also `$`, `{`, `}`). `docs/docs/03-syntax-and-usage/13-script-templates.md` ^f9
  > Within a backtick quoted template literal, `{{ value }}` is also escaped for `$`, `{` and `}`, since those runes can otherwise start a `${ ... }` substitution.
- [web/template] Changed: the security page still says variables are not allowed in script and style and style attributes must be constants; newer syntax pages allow both with context escaping or sanitising. The project moved from forbidding risky holes to escaping them per context. `docs/docs/10-security/01-injection-attacks.md` ^f10
  > `<script>` and `<style>` tags could allow user data to inject vulnerabilities, so variables are not permitted in these sections.
  > Style attributes cannot be expressions, only constants, to avoid escaping vulnerabilities.
  > By default, dynamic CSS values are sanitized to protect against dangerous CSS values that might introduce vulnerabilities into your application.
- [web/template] Changed: `script` templates (Go functions emitted as JS) are now legacy; plain `<script>` tags plus `JSFuncCall`/`JSONString` replace them. `docs/docs/03-syntax-and-usage/13-script-templates.md` ^f11
  > Script templates are a legacy feature and are not recommended for new projects.
- [web/template] Trusted HTML is `templ.Raw(string)`, documented as bypassing all escaping; components written by hand in Go must escape themselves. `docs/docs/03-syntax-and-usage/17-rendering-raw-html.md` ^f12
  > bypassing all HTML escaping and security mechanisms that templ includes, use the `templ.Raw` function.
  > This code is unsafe! In code-only components, you're responsible for escaping the HTML content yourself
- [web/template] Composition: `@component()` renders another component; a component can wrap `{ children... }`; components can be parameters (layouts take `contents templ.Component`). Children travel implicitly in the Go context. `docs/docs/03-syntax-and-usage/10-template-composition.md` ^f13
  > Children are passed to a component using the Go context.
- [web/template] Control flow is Go's own `if`, `switch`, `for` written directly in markup; text starting with those words is parsed as a statement, so it needs quoting. `docs/docs/03-syntax-and-usage/05-statements.md` ^f14
  > The templ parser assumes that text that starts with `if`, `switch` or `for` denotes the start of one of those expressions
- [web/template] Changed: mixing host syntax into text keeps causing parse ambiguity; ADR 0001 made ` @x()` after whitespace a component call, and a future release widens the rule, breaking text like `(@component())`. `docs/adr/0001-inline-templ-element-expressions.md` ^f15
  > The text parser consumed the entire line, including the `@component()` call, because it did not recognize `@` as a delimiter when preceded by whitespace within text content.
  > A future templ release will treat `@` followed by an identifier as a component call unless the `@` follows a letter, digit, or underscore
- [web/template] The generator also checks HTML structure and warns, e.g. child content in a void element. `docs/docs/04-core-concepts/02-template-generation.md` ^f16
  > (!) void element <input> should not have child content
- [web/template] Rendering writes into a pooled 4 KB `bufio.Writer` wrapping the caller's writer; a failing component may leave partial output. `runtime/buffer.go` ^f17
  > var DefaultBufferSize = 4 * 1024 // 4KB
  > A `templ.Component` may write partial output to the `io.Writer` if it returns an error.

## Read

- Docs listed in depth; `runtime/buffer.go`, `runtime/bufferpool.go` (top)

## Not read

- `generator/`: the code emitted per component (size, how literal runs are merged)
- `safehtml/`: templ's port of Google's safehtml sanitisers
- Issue tracker and release notes (no CHANGELOG file in the repo)
