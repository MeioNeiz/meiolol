---
title: Asynchrony is not Concurrency (Loris Cro, 2025)
url: https://kristoff.it/blog/asynchrony-is-not-concurrency/
kind: article
commit:
for: [zig-api-design]
looked: 2026-10-22
depth: docs (prose; code blocks skimmed)
relevance: medium
grade: A/strong
description: Defines asynchrony vs concurrency vs parallelism and why io.async need not be tried or imply concurrency in Zig
---
# Asynchrony is not Concurrency (Loris Cro, 2025)

Why: when to use `io.async` vs `io.concurrent`.

## Assessment

- Evidence: A. Zig team, Jul 2025, follow-up to the Io post.
- Reasoning: strong; definitions, examples, consequences for libraries.
- Interests: ZSF.
- Weigh: `asyncConcurrent` is `concurrent` in 0.16+.

## Findings

- [zig/api] Definitions: asynchrony = may run out of order and stay correct; concurrency = progress several tasks at a time; parallelism = physically simultaneous. ^f1
  > **Asynchrony**: the possibility for tasks to run out of order and still be correct.
- [zig/api] A library can use `io.async` without forcing users off single-threaded blocking I/O. ^f2
  > **This means that a library author can use `io.async` in their code and not force their users to move away from single-threaded blocking I/O.**
- [zig/api] Requesting concurrency documents a correctness requirement and errors on an Io that can't provide it. ^f3
  > This documents in the code that concurrency is required for correctness, which will also let the program error out when attempting to run it over a non-concurrent `Io` implementation.
- [zig/errors] `io.async` can't fail: if no task slot is free, it runs the function directly. ^f4
  > No, it runs the function directly!

## Read

- Prose; code blocks skimmed.
