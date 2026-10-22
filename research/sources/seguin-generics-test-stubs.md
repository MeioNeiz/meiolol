---
title: Using Generics to Inject Stubs when Testing (Karl Seguin, 2025)
url: https://www.openmymind.net/Using-Generics-To-Inject-Stubs-When-Testing/
kind: article
commit:
for: [zig-testing, zig-comptime]
looked: 2026-10-22
depth: docs (whole post)
relevance: medium
grade: B/fair
description: Make a struct generic over its dependency only for tests, keep the public name bound to the real type
---
# Using Generics to Inject Stubs when Testing (Karl Seguin, 2025)

Why: testing seams without vtables.

## Assessment

- Evidence: B. Practitioner, Feb 2025, Zig 0.14; says he uses it rarely.
- Reasoning: fair; admits alternatives and compromises.
- Interests: none known.
- Weigh: a reasonable seam; prefer extracting pure logic first (his own alternative).

## Findings

- [zig/test] Wrap the type as `ClientT(comptime S: type)` and export `pub const Client = ClientT(net.Stream)`; tests instantiate it with a recording stub. ^f1
  > pub const Client = ClientT(net.Stream);
  > The generic, `ClientT`, exists only for testing purposes.
- [zig/test] The stub records writes into an ArrayList on `testing.allocator` so leaks are caught. ^f2
  > Our `TestStream` records all data written.
- [zig/test] His testing stance: fast, not flaky, not brittle; stubs only in specific cases. ^f3
  > I want tests to run fast, not be flaky and not be brittle.
- [zig/test] Alternative he names: pull the framing logic into its own struct and test it directly. ^f4
  > For example, we could extract the message framing logic (in our case, the 4-byte length header), into its own struct).

## Read

- Whole post.
