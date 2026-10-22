---
title: ArrayList and allocator: updating code to 0.15 (Ziggit thread, 2025)
url: https://ziggit.dev/t/arraylist-and-allocator-updating-code-to-0-15/12167
kind: thread
commit:
for: [zig-api-design, zig-memory]
looked: 2026-10-22
depth: docs (whole thread)
relevance: high
grade: B/fair
description: Why 0.15 made ArrayList unmanaged; Andrew Kelley on upgrading one release at a time
---
# ArrayList and allocator: updating code to 0.15 (Ziggit thread, 2025)

Why: the reasons behind allocator-per-call containers.

## Assessment

- Evidence: B. Andrew Kelley and squeek502 (Ryan Liptak, core contributor) post; the
  motivation list is from vulpesx (regular), uncontested by them. Sep-Nov 2025, 0.15.
- Reasoning: fair; list of reasons, no costs.
- Interests: none.
- Weigh: trust the facts; the motivations are a regular's summary.

## Findings

- [zig/api] In 0.15 `ArrayListUnmanaged` became `ArrayList`; the managed one is `std.array_list.Managed`, slated for removal. ^f1
  > To clarify, the actual change was what used to be `ArrayListUnmanaged` is now `ArrayList`. The old `ArrayList` is now `std.array_list.Managed` which will be removed in the future.
- [zig/api] Reasons: smaller struct for fields, explicit about which calls allocate, one implementation, static init with `initBuf`. ^f2
  > it is more explicit, you can more easily tell what functions allocate and vice versa.
  > the struct is now smaller, ideal if you store them in fields.
- [toolchain] Andrew Kelley: upgrade one release at a time with each release's notes; `zig fmt` auto-fixes some changes for two versions. ^f3
  > do the updates one at a time.
  > And sometimes `zig fmt` will simply do the upgrade for you automatically (but we delete that code after 2 versions).
- [zig/api] squeek502: the unmanaged list is not going away, it is renamed. ^f4
  > It will not be removed. It's just been renamed to `ArrayList`.

## Read

- Whole thread.
