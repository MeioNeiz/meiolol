Fetched 2026-10-12 via gh api: lambda-fairy/maud issues 181, 270, 468, 507 (body and all comments).

# #181 Context-aware escaping
state: open, opened 2020-01-13T23:07:41Z by quasicomputational

[The HTML spec defines `<style>` and `<script>` as 'raw text elements'](https://html.spec.whatwg.org/multipage/syntax.html#elements-2), meaning that escapes in their bodies are not processed (hence, e.g., `span:before { content: "Hello!" }` cannot be escaped to `span:before { content: &quot;Hello!&quot; }` - try it in a browser if you don't believe me).

This is a potential footgun with `maud`: the path of less resistance, letting `maud` do the escaping, means that the scripts and styles get mangled; however, naively using `PreEscaped` could theoretically introduce an XSS vulnerability because then there's no check for an errant `</`.

This is related to #88. I'm afraid that the HTML syntax is so complicated that there's no way to avoid a certain amount of context-awareness here. I don't know what the ideal API looks like, or even if `maud` can do much better, but at the very least the docs should point out the footgun here.

## lambda-fairy (OWNER), 2020-03-07T11:24:52Z

Sorry about the delay.

Yeah, I've come around to accepting that this is an issue. We can make some simplifications, as e.g. the lack of legacy code allows us to simply reject cases we don't understand. But overall this will need a lot of design work.

Relevant links:

* [Go `html/template`](https://golang.org/pkg/html/template/)
* [Using type inference to make web templates robust against XSS](https://rawgit.com/mikesamuel/sanitized-jquery-templates/trunk/safetemplate.html)
* [HTML parsing spec](https://html.spec.whatwg.org/multipage/parsing.html)

## lambda-fairy (OWNER), 2021-04-24T12:51:51Z

Some notes before I forget:

- As a prerequisite, we want to validate elements / attributes and throw a hard error when either is unknown. This is because new features are added to HTML all the time, and we can't predict how escaping will work for them.
    - This would imply some configuration (?) for custom elements. Maybe look at how Clippy does config.
- At minimum, we need: `ToHtml`/`ToAttr`, `ToText` (for `<title>` and `<textarea>`), `ToUrl` (for `href` and `<img src>`), `ToTrustedUrl` (for `<script src>`), `ToStyle`/`ToStyleAttr`, `ToScript`/`ToScriptAttr`.
    - Consider whether we need separate traits for "element body" and "attribute value" contexts, or we can get away with one trait for both.
        - Separate traits let us micro-optimize, as e.g. element bodies don't need to escape quotes.
    - Is the `Url` / `TrustedUrl` distinction necessary? Go templates don't do it.
- Consider `serde` integration for safely embedding JSON.
    - It *is* possible to embed JSON in JavaScript safely, but I'd rather not encourage it. I'd prefer either `<script type="application/json">` or the [`<data>` element](https://developer.mozilla.org/en-US/docs/Web/HTML/Element/data) instead.
        - See https://stackoverflow.com/q/9320427/617159
        - It's a bit annoying that `<data>` puts its payload in an attribute, given that both Maud and JSON use double quotes. If people complain, we might need a `ToSingleQuotedAttr` category :smirk: 

## CJ-Jackson (NONE), 2025-08-07T11:21:27Z

I believe many have got used to not having context aware escaping, considering it a security risk, I think it might be a great idea to have that feature behind a feature flag.

## tv42 (NONE), 2026-02-10T17:14:36Z

Instead of Go html/template, you should be looking at https://github.com/google/safehtml

https://static.googleusercontent.com/media/research.google.com/en//pubs/archive/42934.pdf contains some examples.

I think a good approach might be to set up tests where a string is put into each of the possible contexts, and then the generated HTML is parsed with https://crates.io/crates/html5ever and the string extracted and compared to original; then let a fuzzer pick the strings for each of the tests.


# #270 Redesign `PreEscaped` API
state: open, opened 2021-04-24T12:18:58Z by lambda-fairy

The current `PreEscaped` API has a few issues:

- The `PreEscaped` / `Markup` naming was lifted from [`blaze-markup`](https://hackage.haskell.org/package/blaze-markup), which supports both HTML and XML. But Maud was always HTML-only, and the upcoming context-aware escaping effort will deepen this specialization.
    - Let's rename it to just `Html`.
- `PreEscaped` wraps any `T: AsRef<str>`, but I've only seen it used with `String` and `&'static str`.
    - Let's make it wrap `Cow<'static, str>` instead.
- The `PreEscaped` constructor makes it too easy to treat any arbitrary string as HTML. Modern APIs like the [Trusted Types proposal](https://developer.mozilla.org/en-US/docs/Web/API/TrustedHTML) force the user to do some sanitizing/escaping first, or at least acknowledge the security risk if they don't.
    - Let's remove the public constructor, and replace it with...
      ```rust
      impl Html {
          pub sanitize(value: &str) -> Self;
          pub from_trusted(value: impl Into<Cow<'static, str>>) -> Self;
      }
      ```
      Notice how the safe (`sanitize`) option is shorter!

## zopieux (CONTRIBUTOR), 2021-11-10T20:09:28Z

Just wanted to mention that `PreEscaped` was confusing to me when I discovered maud. So :+1: on that rename, it would be a net positive wrt discoverability, IMO.

## JohnDowson (NONE), 2022-03-29T11:51:17Z

There needs to be consideration for making sure it is possible to serialize `Html` for use-cases like pushing DOM updates over websocket messages. Either Html need to be `Into<String>` or maud needs to have a `serde` feature.


# #468 Bug: PreEscaped into attribute generates invalid HTML
state: open, opened 2025-01-29T02:33:54Z by Porges

This is related to #181 but I don't think it has been called out explicitly as a problem there. If you have some `Markup`/`PreEscaped` and slot it into an attribute then that is passed on without any further escaping, but `Markup` is escaped to be valid HTML not to be valid attribute content.

For example:

```rs
let title = maud::html! {
    "With " a href="https://example.com" { "a link in it" }
};

let result = maud::html! {
    meta property="og:title" content=(title);
};

println!("{}", result.into_string());
```

Output:

```
<meta property="og:title" content="With <a href="https://example.com">a link in it</a>">
```

There are multiple possible solutions here:
- either the input needs to be re-escaped for the correct context
- or putting already-encoded input from the wrong context in should produce an error (since even the escaped version here is going to be dubious, even if it's safe, probably the intent is _really_ to use the equivalent of `textContent`, but that cannot be decided in advance)

## Porges (NONE), 2025-01-29T03:04:02Z

Ah, looks like this might have been started to be addressed in #460?

## lambda-fairy (OWNER), 2025-02-02T11:43:11Z

Yes this is a known issue. I don't think there's an easy way out of it without context-aware escaping. I'll take a note of it when I work on #322.


# #507 JSON spliced into an attribute value breaks out of the attribute
state: open, opened 2026-08-29T07:45:11Z by allenap

`Render for serde_json::Value` (and `Json<T>`) writes JSON directly into the output buffer with no HTML escaping. That is correct for element content, but in an attribute value the JSON's own quotes terminate the attribute early, and the remainder is parsed as markup. An attacker who controls any string in the JSON therefore controls attributes on that element.

### Reproduction

```rust
use maud::html;

let untrusted = "x onmouseover=alert(1) y";
let value = serde_json::json!({ "name": untrusted });
println!("{}", html! { div data-user=(value) {} }.into_string());
```

Output:

```html
<div data-user="{"name":"x onmouseover=alert(1) y"}"></div>
```

An HTML tokenizer might read this as:

| token | value |
| --- | --- |
| `data-user` | `{` |
| `name":"x` | *(empty)* |
| `onmouseover` | `alert(1)` |
| `y"}"` | *(empty)* |

`onmouseover=alert(1)` is a live event handler, injected from string data.

### Impact

Any template that splices JSON into an attribute is vulnerable, e.g. the common pattern of passing server state to client-side JavaScript:

```rust
html! { div id="app" data-state=(state) {} }
```

Element content – including `<script>` tags, which the module is designed for – is **not** affected. The escaping of `<`, `>`, and `&` means the output can never open or close a tag there.

### Affected APIs

- `impl Render for serde_json::Value`
- `impl Render for Json<T>`
- `impl Render for serde_json::value::RawValue`, if that lands (#506)

All are part of the `json` module, originally added in #483, which is still under `## [Unreleased]` in the changelog. **No released version of maud is affected**, so this can be fixed without a compatibility break.

### Root cause

Maud has no notion of attribute context. Splices in attribute values and in element content go through the same code path in `maud_macros/src/generate.rs`. Escaping is therefore entirely the responsibility of each `Render` impl. `Render for str` escapes via `Escaper`, so it is safe in both positions. The JSON impls deliberately write raw bytes so that `<` escapes survive, which makes them safe in element content but not in an attribute.

### Why this can't be fixed in the JSON formatter

The problematic quotes are the JSON string delimiters, emitted by serde_json's `Formatter::begin_string` / `end_string`.  They cannot be escaped as `\u0022` without producing invalid JSON – a JSON string must begin with a literal `"`. Quotes *inside* a string are already escaped to `\"` by serde_json before the custom formatter sees the fragment, and `\` carries no meaning to an HTML attribute parser, so that does not help either.

Any JSON document containing a string will always emit `"`.

### How might we fix this

1. **Document the restriction.** #506 does this already. It's cheap but it leaves a sharp edge.
2. **Escape at the attribute layer.** Have `generate.rs` wrap attribute-value splices in an escaping adapter. This would change behaviour for every `Render` impl in attribute position, including `PreEscaped`.
3. **Distinguish the two contexts in the trait.** For example a separate method for attribute rendering, defaulting to `render_to`, that the JSON impls override to escape quotes.



