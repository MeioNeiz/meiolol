---
title: std.Io.Writer.Allocating ate all my memory (Karl Seguin, 2026)
url: https://www.openmymind.net/std-io-writer-allocating-ate-my-memory/
kind: article
commit:
for: [zig-memory, zig-api-design]
looked: 2026-10-22
depth: docs (whole post)
relevance: medium
grade: C/fair
description: Writer.Allocating's drain over-reserves capacity for large single writes; ArrayList doesn't
---
# std.Io.Writer.Allocating ate all my memory (Karl Seguin, 2026)

Why: choosing between `ArrayList(u8)` and `Writer.Allocating` for byte building.

## Assessment

- Evidence: C. One practitioner's measurement on 0.16 (Jul 2026) of what he calls a
  bug; not confirmed upstream in the post. He credits Claude with spotting it.
- Reasoning: fair. Numbers and the code path; no upstream issue link.
- Interests: none known.
- Weigh: verify on 0.17 before relying on it.

## Findings

- [zig/memory] A 1025-byte `writeAll` into a 1024-capacity `Writer.Allocating` grows it to 3204 bytes; an `ArrayList(u8)` grows to 1665. ^f1
  > Like me, you might be surprised to see **3204**.
- [zig/memory] Cause he reports: `drain` reserves the splat length for every slice, so a plain write reserves twice its size. ^f2
  > For the common case where `data.len == 1` and `splat == 1`, we're actually reserving 2x the memory
- [zig/api] For simple appending of bytes he suggests staying with `ArrayList(u8)`. ^f3
  > If your use-case is simple, if you're just appending bytes, you might want to stick with it.

## Read

- Whole post.
