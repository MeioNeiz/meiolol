---
title: 'Ziggit: Writing an entire web frontend in Zig with wasm-api, when does it make sense? (2023)'
url: https://ziggit.dev/t/writing-an-entire-web-frontend-in-zig-with-wasm-api-when-does-it-make-sense/2009
kind: thread
commit: 
for: [zig-only-frontend]
looked: 2026-10-22
depth: docs (all 3 posts)
relevance: medium
grade: B/fair
description: Short Ziggit thread; Loris Cro (Zig Software Foundation) on why autodoc first stayed JS: wasm performance hit, DOM reference passing, strings duplicated on both sides
---
# Ziggit: Writing an entire web frontend in Zig with wasm-api, when does it make sense? (2023)

Why: what do Zig people say about Zig-driven frontends?

## Assessment

- Evidence: B for kristoff's post (Loris Cro, ZSF VP of community, on Zig's own
  autodoc); others are opinions. October 2023, before Zig's autodoc rewrite and before
  JS string builtins shipped.
- Reasoning: fair.
- Interests: none.
- Weigh: the string point is now partly answered by JS string builtins (UTF-16 based,
  so a UTF-8 Zig program still converts).

## Findings

- [web/wasm] Autodoc first rejected wasm because of the performance hit against plain
  JS. ^f1
  > With Autodoc we originally considered using wasm but it seemed that the performance hit would have been non-insignificant compared to just using JS.
- [web/wasm] The pain points: passing DOM references around, and strings that cannot be
  shared, so they are duplicated on both sides. ^f2
  > even setting aside the clunkyness of passing around references to dom elements, the wasm side and the JS side can’t share strings
- [web/wasm] He doubted a string interop proposal would help without JS engines moving
  to UTF-8. ^f3
  > JS engines seem to hate the idea of switching to utf8
- [web/wasm] Another poster: the main reason for a non-JS frontend is not wanting JS;
  JS may still be the best option. ^f4
  > I think the main reason to use non-JS frameworks for Web frontend is, tgat you don’t want to use JavaScript.

## Read

- All three posts.
