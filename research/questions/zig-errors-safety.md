---
status: answered
parent: zig-good-practice
priority: soon
area: code
tags: [zig/errors, zig/safety]
description: How should Zig code handle errors and enforce invariants: error sets, diagnostics, assertions, panics, undefined behaviour and build modes?
---
# How should Zig code handle errors and enforce invariants: error sets, diagnostics, assertions, panics, undefined behaviour and build modes?

Feeds: docs/zig/README.md (the Zig practice guide, split by topic), then applying it to the repo

## Answer

Errors are codes for branching; details go out of band (C1, C2). Consume errors with
`try`, `catch` default, `catch unreachable` only as a proven assertion, or `catch |err|
switch`; compare with switch, never `==` (C3, C4). Use inferred sets inside, named and
doc-commented sets composed with `||` at boundaries; avoid `anyerror` (C5). Translate
errors at boundaries with an exhaustive switch (C6). Diagnostics live on the
implementation (`err` field), in an optional out-param, or a factory struct; user-input
errors become a list, only OOM returns (C2, C7). 0.17 removed `errdefer |err|`: split the
function (C8). Separate bugs (assert, crash) from operating errors (handle) (C9). Assert
arguments, invariants and results; pair them; split compound asserts; comptime-assert
constant relations and sizes (C10, C11). Asserts are checks in debug and safe builds and
optimiser facts in fast and small; keep safety on in shipped builds unless measured
(C12, C13). Gate expensive checks on debug (C14). Each `unreachable` says why (C15).
`error.Canceled` propagates (C16).

## Claims

- C1: Error sets are codes for control flow; reporting detail travels separately. for: [[matklad-error-codes-control-flow#^f2]], [[matklad-error-codes-control-flow#^f10]], [[zig-015-release-notes#^f13]]
- C2: Generic interfaces return one opaque error and store details on the implementation or a Diagnostics struct. for: [[zig-std-io#^f11]], [[zig-std-io#^f12]], [[zig-std-json-fmt-args#^f7]], [[zig-clap-repo#^f8]], [[ziggit-error-payload-data#^f1]]
- C3: Consume errors with try, catch default, catch unreachable as assertion, or catch switch. for: [[zig-langref-017-b#^f3]], [[zig-langref-017-b#^f5]], [[seguin-learning-zig-language-overview-2#^f1]]
- C4: Compare errors with switch, never `==`, to avoid silent anyerror upcasts. for: [[tigerbeetle-tidy#^f4]]
- C5: Named, doc-commented error sets composed with `||`; no anyerror. for: [[zig-std-allocators#^f26]], [[zig-std-io#^f3]], [[zls-repo#^f18]], [[zig-langref-017-b#^f2]], [[zig-langref-017-b#^f10]]
- C6: Translate errors at boundaries with an exhaustive switch so new inner errors fail to compile. for: [[zig-std-containers#^f14]], [[ghostty-repo#^f31]]
- C7: User-input errors accumulate as diagnostics; reporting goes through constructor functions. for: [[ghostty-repo#^f33]], [[matklad-diagnostics-factory#^f1]], [[matklad-diagnostics-factory#^f4]], [[superhtml-repo#^f17]]
- C8: 0.17 removes `errdefer |err|`; split the function and catch at the call. for: [[zig-017-release-notes#^f21]]
- C9: Assertions are for programmer errors, error unions for operating errors. for: [[tigerbeetle-tiger-style#^f6]], [[roc-zig-compiler#^f2]], [[river-repo#^f16]], [[tigerbeetle-code#^f16]]
- C10: Assert arguments, return values and invariants, and pair checks on two paths. for: [[tigerbeetle-tiger-style#^f7]], [[tigerbeetle-blog-pair-assertions#^f2]], [[matklad-defer-patterns#^f3]]
- C11: Split compound asserts, write implications as `if (a) assert(b)`, comptime-assert constants and sizes. for: [[tigerbeetle-tiger-style#^f9]], [[tigerbeetle-blog-asserting-implications#^f1]], [[tigerbeetle-code#^f14]], [[zig-compiler-dod#^f5]]
- C12: unreachable and assert panic in debug and safe builds and are optimiser assumptions in fast and small. for: [[zig-langref-017-a#^f118]], [[zig-langref-017-b#^f66]], [[kristoff-fix-your-asserts#^f3]]
- C13: Ship with safety checks on (ReleaseSafe) unless profiling says otherwise. for: [[tigerbeetle-code#^f4]], [[bun-in-rust#^f7]], [[kristoff-fix-your-asserts#^f10]] against: [[mitchellh-ghostty-gtk-rewrite#^f6]]
- C14: Expensive integrity checks are a separate debug-only tier. for: [[ghostty-repo#^f26]], [[kristoff-fix-your-asserts#^f8]], [[tigerbeetle-code#^f9]]
- C15: Every unreachable or catch unreachable states its reason on the line. for: [[roc-zig-compiler#^f3]], [[zls-repo#^f19]]
- C16: error.Canceled is propagated; only the requester may swallow it. for: [[zig-016-release-notes#^f7]], [[zig-talk-async-io-zigtoberfest#^f7]], [[matklad-io-threaded#^f4]]
- C17: Assert arguments always evaluate; never put side effects in them. for: [[kristoff-fix-your-asserts#^f7]], [[bun-in-rust#^f8]]
- C18: Pointers into union payloads are not protected by safety checks across a write. for: [[matklad-memory-safety-hardest#^f1]]
- C19: Error return traces make `try` debuggable, but only debug builds have them by default. for: [[zig-langref-017-b#^f11]], [[zig-langref-017-b#^f12]]

## Disagreements

- Shipping mode: TigerBeetle, Loris Cro, River, ZLS: safe builds; Ghostty ships fast and
  relies on debug safety and Valgrind. For a data pipeline, safe.
- Assert density: Tiger Style says two per function; measured 3.7 overall but 35% of
  functions have none; ZLS ~6, River ~12 per 1000 lines. Density where state is subtle.
- Assert cost: Ghostty saw std assert not removed in fast builds on 0.15.2 (15-20%);
  unverified on 0.17.

## Open

- Does 0.17 still leave `std.debug.assert` calls in fast builds (Ghostty's quirk)?
- Whether to enable error return traces in safe builds for crash reports
