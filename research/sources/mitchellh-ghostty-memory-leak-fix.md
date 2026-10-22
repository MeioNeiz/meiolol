---
title: "Finding and Fixing Ghostty's Largest Memory Leak (Mitchell Hashimoto)"
url: https://mitchellh.com/writing/ghostty-memory-leak-fix
kind: article
for: [zig-memory, zig-testing]
looked: 2026-10-22
depth: docs (full)
relevance: high
grade: B/strong
description: Jan 2026 post-mortem: PageList pool vs direct mmap pages, ownership inferred from size desynced in a reuse fast path, 37 GB leak; fix, VM tags, and Ghostty's leak-prevention stack
---
# Finding and Fixing Ghostty's Largest Memory Leak (Mitchell Hashimoto)

Why: what does a real Zig memory bug in a well-tested codebase look like, and what caught it?

## Assessment

- Evidence: B. First-hand post-mortem of a confirmed, multi-user bug; fix PR linked; the
  current code ([[ghostty-repo#^f18]]) shows the lesson carried further.
- Reasoning: strong. Explains the design, why it was sound, the exact desync, why tests
  missed it, and the simpler fix chosen over adaptive strategies.
- Interests: none (states no AI wrote the text).
- Weigh: the general lesson (don't infer ownership from a size or other derived property)
  applies to any pool-plus-heap design.

## Findings

- [zig/memory] Pages come from a pool of standard-size mmap blocks; bigger pages bypass the pool with their own mmap. ^f1
  > to avoid constant syscalls, we use a **memory pool**. When we need a new page, we pull from the pool.
- [zig/memory] Free decided ownership from size: up to standard size back to the pool, larger munmap'd. ^f2
  > If the page is `<= standard size`: return it to the pool
- [zig/memory] [zig/perf] Hot-path optimisation: at the scrollback limit the oldest page is reused as the newest, with zero allocations. ^f3
  > It requires zero allocations and uses only some quick pointer manipulations to move the page from the front to the back of the list.
- [zig/memory] Bug: the reuse reset size metadata to standard but kept the large mapping, so free took it for a pool page and never munmap'd it. ^f4
  > The underlying memory was still the large non-standard `mmap` allocation, but now the PageList _thought_ it was standard sized.
- [zig/memory] Rare-by-design paths hide bugs until a new workload hits them (many graphemes plus heavy scrollback); one user saw 37 GB after 10 days. ^f5
  > the issue is that non-standard pages are rare by design.
- [zig/memory] Fix: never reuse a non-standard page; destroy it and take a fresh standard one. ^f6
  > The fix is conceptually simple: **never reuse non-standard pages**.
- [zig/memory] He chose the simple fix over adaptive sizing until data says otherwise. ^f7
  > This change is simple, fixes the bug, and aligns with our current assumptions.
- [zig/memory] (inferred) The code has since stopped inferring ownership from size: Node carries an explicit `owned` enum with no default. See [[ghostty-repo#^f18]]. ^f8
- [zig/memory] An Allocator wrapper tags macOS VM regions so the PageList's memory is visible in OS tools; tests get testing.allocator. ^f9
  > This lets us tag our PageList memory allocations with a specific identifier that shows up in various tooling.
  > if (builtin.is_test) return std.testing.allocator;
- [zig/test] [zig/memory] Leak defences: leak-detecting allocators in debug builds and tests, Valgrind over the full unit suite in CI on every commit, Instruments for Swift, Valgrind on GTK PRs. ^f10
  > The CI runs `valgrind` on our full unit test suite on every commit to find more than just leaks, such as undefined memory usage.
- [zig/test] None caught it because tests didn't reproduce the conditions; the fix adds a test that does. ^f11
  > The merged PR includes a test that does reproduce the leak to prevent regressions in the future.

## Read

- Full post

## Not read

- PR 10251
