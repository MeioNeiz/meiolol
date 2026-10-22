---
title: Cancelation Terminology (matklad, 2026-08-31)
url: https://matklad.github.io/2026/08/31/cancelation-terminology.html
kind: article
commit: 
for: [zig-api-design]
looked: 2026-10-22
depth: docs (whole post)
relevance: medium
grade: B/strong
description: Synchronous cancelation (control flow), asynchronous cancelation (a protocol), graceful shutdown (app pattern); TigerBeetle Grid.cancel vs StateMachine.reset; crash-only
---
# Cancelation Terminology (matklad, 2026-08-31)

Why: thinking about cancelation with std.Io (0.16+). Language neutral, TigerBeetle
examples.

## Assessment

- Evidence: B. TigerBeetle code examples (grid.zig, state_machine.zig, client.zig).
- Reasoning: strong. Clear distinctions with examples and why each matters.
- Interests: none.
- Weigh: useful vocabulary; crash-only is a design stance.

## Findings

- [zig/api] [zig/errors] Synchronous cancelation is control flow: returning an error
  unwinds and runs cleanup (`defer`). ^f1
  > The primary source of synchronous cancelation is error handling
- [zig/api] Asynchronous cancelation is a protocol: request, then wait for
  acknowledgement, because e.g. a buffer handed to a thread or io_uring must stay tied
  up until the work ends. ^f2
  > asynchronous cancelation is a communication protocol between two parties.
- [zig/api] CPU work checks cancelation per chunk, not per byte, so the requester waits up
  to one chunk. ^f3
  > What you’d want is to split the buffer into reasonably-sized chunks, and check the cancelation status after every chunk.
- [zig/api] TigerBeetle cancels only Grid asynchronously and resets everything above it
  synchronously, instead of propagating asynchrony up the stack. ^f4
  > What we do instead is asynchronously canceling _just_ the `Grid` directly, and then synchronously `reset`ing everything else.
- [zig/api] TigerBeetle is crash-only, no graceful shutdown; if you survive power loss,
  Quit can be SIGKILL, which also tests that path. ^f5
  > We don’t do graceful shutdown at TigerBeetle — it’s crash only all the way.
  > you might as well implement the Quit button by SIGKILLing yourself, simultaneously simplifying the implementation and increasing testing coverage for powerloss scenarios.

## Read

- Whole post.
