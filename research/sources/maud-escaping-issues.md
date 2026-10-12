---
title: 'maud issues 181, 270, 468, 507: context-aware escaping, PreEscaped redesign'
url: https://api.github.com/repos/lambda-fairy/maud/issues/181
kind: thread
for: [zig-html-templates]
looked: 2026-10-12
depth: listed (four issues, bodies and all comments)
relevance: high
grade: B/strong
description: maud's open issues on context-aware escaping, the PreEscaped redesign, and two attribute break-outs that follow from escaping by one rule everywhere
---
# maud issues 181, 270, 468, 507: context-aware escaping, PreEscaped redesign

Why: what goes wrong with one escape for every position, and what would the maintainer
change? Raw holds #181 (2020, open), #270 (2021, open), #468 (2025, open), #507 (open).

## Assessment

- Evidence: B. The maintainer's own design notes and reproduced bugs in an 11-year-old
  library ([[maud-repo]]); the redesign is planned, not shipped, so untested.
- Reasoning: strong. Reproductions with output, root cause, options and costs (#507);
  the maintainer lists the contexts needed and open trade-offs (#181).
- Interests: none known.
- Weigh: the bugs are concrete and trustworthy; the proposed trait list is a sketch.

## Findings

- [web/template] `<script>` and `<style>` bodies are raw text: HTML escaping mangles them, and `PreEscaped` skips the check for a stray `</`. #181 ^f1
  > the path of less resistance, letting `maud` do the escaping, means that the scripts and styles get mangled
  > naively using `PreEscaped` could theoretically introduce an XSS vulnerability because then there's no check for an errant `</`.
- [web/template] The maintainer accepts it and says a new design can reject what it does not understand, pointing at Go html/template. #181 ^f2
  > We can make some simplifications, as e.g. the lack of legacy code allows us to simply reject cases we don't understand.
- [web/template] Planned prerequisite: hard error at compile time on unknown elements or attributes, since escaping for unknown ones can't be predicted. #181 ^f3
  > As a prerequisite, we want to validate elements / attributes and throw a hard error when either is unknown.
- [web/template] Planned minimum set of contexts: HTML/attribute, text (title, textarea), URL, trusted URL (script src), style, script. #181 ^f4
  > At minimum, we need: `ToHtml`/`ToAttr`, `ToText` (for `<title>` and `<textarea>`), `ToUrl` (for `href` and `<img src>`), `ToTrustedUrl` (for `<script src>`), `ToStyle`/`ToStyleAttr`, `ToScript`/`ToScriptAttr`.
- [web/template] For data to scripts the maintainer prefers `<script type="application/json">` or `<data>` over splicing JSON into JavaScript. #181 ^f5
  > I'd prefer either `<script type="application/json">` or the [`<data>` element](https://developer.mozilla.org/en-US/docs/Web/HTML/Element/data) instead.
- [web/template] A commenter suggests testing by putting a string in each context, parsing the output with a real HTML parser, and fuzzing that the string comes back unchanged. #181 ^f6
  > set up tests where a string is put into each of the possible contexts, and then the generated HTML is parsed with https://crates.io/crates/html5ever and the string extracted and compared to original
- [web/template] Regret: `PreEscaped(...)` makes trusting any string too easy; the plan is to rename to `Html`, drop the public constructor, and offer `sanitize` (shorter) and `from_trusted`. #270 ^f7
  > The `PreEscaped` constructor makes it too easy to treat any arbitrary string as HTML.
  > Notice how the safe (`sanitize`) option is shorter!
- [web/template] Bug: `Markup` spliced into an attribute is not re-escaped, so a component's HTML breaks out of `content="..."`; the maintainer says there's no easy fix without context-aware escaping. #468 ^f8
  > If you have some `Markup`/`PreEscaped` and slot it into an attribute then that is passed on without any further escaping, but `Markup` is escaped to be valid HTML not to be valid attribute content.
  > I don't think there's an easy way out of it without context-aware escaping.
- [web/template] Bug: JSON escaped for script bodies, spliced into an attribute, ends the attribute at its first `"` and injects an event handler; root cause is one code path for attribute and body splices. #507 ^f9
  > Maud has no notion of attribute context. Splices in attribute values and in element content go through the same code path
  > An attacker who controls any string in the JSON therefore controls attributes on that element.
- [web/template] (inferred) Both bugs come from the same choice: escaping decided by the value's type, not the hole's position. A hole's position (body, attribute, URL attribute, script, style) is known at compile time in a structured template, so the escape can be picked there. ^f10

## Read

- Issues #181, #270, #468, #507: bodies and all comments

## Not read

- #322 and PR #460 (referenced as the start of a fix)
- Go html/template and google/safehtml, which #181 points to as prior art
