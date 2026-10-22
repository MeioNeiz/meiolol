---
title: Ghostty Devlog 004 (Mitchell Hashimoto)
url: https://mitchellh.com/writing/ghostty-devlog-004
kind: article
for: [zig-comptime]
looked: 2026-10-22
depth: docs (full)
relevance: low
grade: B/fair
description: Sept 2023 devlog; Zig-relevant part is XTGETTCAP, a comptime-generated lookup table built from the same source as the terminfo file
---
# Ghostty Devlog 004 (Mitchell Hashimoto)

Why: concrete comptime-table use in Ghostty.

## Assessment

- Evidence: B. First-hand, shipped feature; most of the post is terminal news.
- Reasoning: fair. One clear benefit (single source, always in sync), perf secondary.
- Interests: project promotion.
- Weigh: one finding of use; the gist with the code wasn't read.

## Findings

- [zig/comptime] Every XTGETTCAP request and response is generated at comptime from the same source that generates the terminfo file, so the two can't drift. ^f1
  > This is generated from the same source file that generates our actual terminfo file, so our terminfo and XTGETTCAP are always perfectly in sync.
- [zig/comptime] [zig/perf] The runtime path is a comptime lookup table: no allocation or formatting, a stable pointer written to the pty. ^f2
  > We don't have to perform any allocations, string formatting, etc.

## Read

- Full post

## Not read

- The linked gist with the comptime generator
