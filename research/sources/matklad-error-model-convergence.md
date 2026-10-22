---
title: The Second Great Error Model Convergence (matklad, 2025-12-29)
url: https://matklad.github.io/2025/12/29/second-error-model-convergence.html
kind: article
commit: 
for: [zig-errors-safety]
looked: 2026-10-22
depth: docs (whole post)
relevance: medium
grade: B/fair
description: Go, Rust, Swift and Zig converged on call-site marked fallibility, a separate panic path for bugs and errors as values; the open problem is the error value's shape
---
# The Second Great Error Model Convergence (matklad, 2025-12-29)

Why: where Zig's error model sits and its unresolved tension. Version neutral.

## Assessment

- Evidence: B. Expert survey of languages; no data.
- Reasoning: fair. Clear framing, the tension stated; no recommendation beyond it.
- Interests: none.
- Weigh: background for the guide's errors chapter: panic vs error split.

## Findings

- [zig/errors] Modern languages mark fallible calls at the call site (`try make_widget()`);
  changing infallible to fallible ripples through the call chain, adding a new error
  doesn't. ^f1
  > functions that can fail are annotated at the call side.
- [zig/safety] A separate mechanism for detectable bugs; in Zig and Swift panic aborts the
  process. ^f2
  > In Swift and Zig, panic aborts the entire process.
- [zig/safety] [zig/errors] An operational error from a lower layer can be a programming
  error for the layer above, so there is a way to escalate a result to a panic; bugs in
  ordinary code are catastrophic and invisible in types. ^f3
  > Operational error of a lower layer can be classified as a programming error by the layer above
- [zig/errors] Handling is localised to one expression: `make_widget() catch |err| switch
  (err) { error.NotFound => default_widget(), }`. ^f4
  > let widget = make_widget() catch |err| switch (err) {
- [zig/errors] Tension: low levels want exhaustive errors, high levels want to string
  subsystems together; midpoint is poorly served and leads to "bag of everything" types. ^f5
  > But overall, it feels like “midpoint” error handling is poorly served by either extreme.
- [zig/errors] Zig assumes a mostly closed world and infers who can throw what across
  functions. ^f6
  > Zig makes an interesting choice of assuming mostly closed-world compilation model, and relying on cross-function inference to learn who can throw what.

## Read

- Whole post.

## Not read

- Joe Duffy "The Error Model" (linked): other author; lead.
