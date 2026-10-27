---
title: 'RFC 9110: HTTP Semantics (IETF, 2022)'
url: https://www.rfc-editor.org/rfc/rfc9110.txt
kind: spec
commit: 
for: [site-url-scheme]
looked: 2026-10-27
depth: docs (section 10.2.2 Location)
relevance: medium
grade: A/strong
description: The HTTP standard; read for whether a redirect keeps the original URL's fragment
---
# RFC 9110: HTTP Semantics

Why: old URLs carry state in the fragment (#role=bot, #pool=...), which the server never
sees. Does a 301 keep it?

## Assessment

- Evidence: A. The IETF standard.
- Reasoning: strong.
- Interests: none.
- Weigh: browsers follow it; check our wasm still reads the old keys.

## Findings

- [seo] A redirect whose Location has no fragment inherits the original fragment. ^f1
  > If the Location value provided in a 3xx (Redirection) response does not have a fragment component, a user agent MUST process the redirection as if the value inherits the fragment component
- [seo] (inferred) So /champion/karthus.html#role=bot 301 to /champions/karthus arrives as /champions/karthus#role=bot, and the page's wasm can map it to /champions/karthus/bot. ^f2

## Read

- section 10.2.2

## Not read

- everything else
