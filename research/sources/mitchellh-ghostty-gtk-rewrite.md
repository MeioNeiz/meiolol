---
title: We Rewrote the Ghostty GTK Application (Mitchell Hashimoto)
url: https://mitchellh.com/writing/ghostty-gtk-rewrite
kind: article
for: [zig-memory, zig-errors-safety]
looked: 2026-10-22
depth: docs (full)
relevance: high
grade: B/strong
description: Aug 2025: GTK app rewritten on GObject with every change run under Valgrind; Zig core had one leak and one undefined access, dozens of issues all at C API boundaries
---
# We Rewrote the Ghostty GTK Application (Mitchell Hashimoto)

Why: empirical memory-safety results from a large Zig codebase, and where its bugs cluster.

## Assessment

- Evidence: B. First-hand result over a full rewrite with every PR under Valgrind; counts are
  rough ("dozens") and self-reported.
- Reasoning: strong. Separates Zig-side from C-boundary issues, names the tools that caught
  them, says release builds lack the protections, avoids overclaiming.
- Interests: a Zig advocate and donor; he flags the flame-war risk himself.
- Weigh: one project; strong as a data point that Debug-build safety plus leak-checking
  allocators work, and that C boundaries need Valgrind.

## Findings

- [zig/memory] Keeping Zig-owned objects outside GObject's refcounting caused a whole class of bugs where one side's memory was freed and not the other's. ^f1
  > the Zig memory or the GTK memory has been freed, but not both.
- [zig/memory] Fix: wrap the Zig Config in a reference-counted GObject, so the old config frees when its last reference goes, instead of updating the whole GUI before freeing. ^f2
  > When the old configuration no longer has any references, it frees. Conceptually much simpler.
- [zig/test] [zig/memory] Every change in the rewrite ran under Valgrind, with a suppression file mostly supplied by GTK. ^f3
  > from the first PR to the last, we've run every change and Ghostty feature through Valgrind
- [zig/safety] The Zig core showed one leak (inside a third-party C call) and one undefined memory access, fewer than he expected given its memory tricks. ^f4
  > **Our Zig codebase had one leak and one undefined memory access.**
- [zig/safety] Protections that did the work: the leak-detecting debug allocator and safety checks in Debug and test builds, plus Zig's Valgrind integration that marks memory set to `undefined`. ^f5
  > Zig emits a Valgrind client request to mark some memory as undefined whenever you set a value as `undefined` (keyword) in Zig.
- [zig/safety] He concludes Debug-only safety works even though release builds have none of it. ^f6
  > This experience has really shown me that this is _working_, despite not having any of these protections in our release builds.
- [zig/safety] [zig/api] Every other issue (dozens) sat on C API boundaries, where lifetime is transferred or blurred; safety there is only as good as the wrapper. ^f7
  > **All other memory issues revolved around C API boundaries.**
  > the safety you're guaranteed is only as good as understanding the semantics of the API and writing a good wrapper.
- [zig/safety] Example of a boundary bug: a GObject WeakRef not cleared in dispose caused rare undefined access hours or days later; Valgrind found it. ^f8
  > That undefined memory access happens to be _fine_ 99% of the time, but once in awhile it causes a crash.

## Read

- Full post

## Not read

- The gtk-ng PRs 7961 and 8235; the GObject class wrappers in `src/apprt/gtk/class/`
