# 7. Assertions, safety and build modes

## 7.1 What assert and unreachable do

`std.debug.assert(ok)` is `if (!ok) unreachable`. In debug and safe builds it panics; in
fast and small builds the optimiser assumes it never happens [[zig-langref-017-a#^f118]]:

```zig
// This is how std.debug.assert is implemented
fn assert(ok: bool) void {
    if (!ok) unreachable; // assertion failure
}
```

Consequences [[kristoff-fix-your-asserts#^f7]], [[kristoff-fix-your-asserts#^f8]]:

- assert only what is truly invariant: in fast builds a wrong assert is undefined
  behaviour, not a no-op
- it is a function, not a macro: arguments are evaluated in every mode, so never put side
  effects in them [[bun-in-rust#^f8]], and gate expensive conditions:

```
// research/raw/kristoff-fix-your-asserts.md:125
const builtin = @import("builtin");

if (builtin.mode == .Debug) {
  var condition = ...;
  // whatever bookkeeping is necessary
  // to compute the condition
  assert(condition == .ok);
}
```

(In 0.17 spell it `.debug`; safety.md 7.3.)

- prefer a type that makes the bad state unrepresentable over an assert
  [[kristoff-fix-your-asserts#^f1]]

## 7.2 Bugs crash; operating errors are handled

The line every respected source draws: an assertion checks a programmer error, which
you cannot handle because you cannot predict it; an operating error (bad input, missing
file, disk corruption, OOM) is expected and must be handled [[tigerbeetle-tiger-style#^f6]],
[[roc-zig-compiler#^f2]]. TigerBeetle cites an OSDI'14 study: 92% of catastrophic
failures came from mishandled non-fatal errors [[tigerbeetle-tiger-style#^f21]].

TigerBeetle's grid read shows both on one path: corruption from disk returns an enum,
what only a bug could break is asserted [[tigerbeetle-code#^f16]]:

```zig
// tigerbeetle src/vsr/grid.zig:1395 @ 0450c32
        fn read_block_validate(block: BlockPtrConst, expect: struct {
            address: u64,
            checksum: u128,
        }) ReadBlockResult {
            const header = mem.bytesAsValue(vsr.Header.Block, block[0..@sizeOf(vsr.Header)]);

            if (!header.valid_checksum()) return .invalid_checksum;
            if (header.command != .block) return .unexpected_command;

            assert(header.size >= @sizeOf(vsr.Header));
            assert(header.size <= constants.block_size);
```

Roc makes the bug side one helper with a message in safe builds:

```zig
// roc src/base/invariant.zig:1 @ 55a9d652
//! The one way the compiler handles a violated compiler invariant
//! (design.md).

const std = @import("std");

/// A violated compiler invariant: an assumption that can fail only if the
/// compiler has a bug. Builds with runtime safety panic with this message;
/// optimized builds treat the path as unreachable, so release builds carry no
/// runtime check for it.
pub inline fn invariant(comptime fmt: []const u8, args: anytype) noreturn {
    if (std.debug.runtime_safety) std.debug.panic(fmt, args);
    unreachable; // callers reach this only when a compiler invariant is violated, which design.md makes undefined in optimized builds
}
```

## 7.3 Build modes in 0.17

0.17 renamed them: `debug`, `safe`, `fast`, `small` (`-Osafe`), under `std.lang.Optimize`;
`builtin.mode` is deprecated for `builtin.optimize`, `std.builtin` for `std.lang`
[[zig-langref-017-b#^f63]], [[zig-017-release-notes#^f31]]. The old capitalised names
still compile as deprecated declarations until 0.18.

Safety-checked illegal behaviour panics in debug and safe and is undefined in fast and
small. The checked cases: unreachable, index out of bounds, negative to unsigned, cast
truncates, integer overflow, exact shifts, division by zero, exact division remainder,
unwrapping null or an error, invalid error code, invalid enum or error-set cast, pointer
alignment, wrong union field, float-to-int out of range, pointer cast to null
[[zig-langref-017-b#^f68]]. extern and packed unions have no field check.

`@setRuntimeSafety(bool)` overrides the mode for a scope, in both directions
[[zig-langref-017-b#^f60]]:

```zig
// research/raw/zig-langref-017.md:11038
test "@setRuntimeSafety" {
    // The builtin applies to the scope that it is called in. So here, integer overflow
    // will not be caught in ReleaseFast and ReleaseSmall modes:
    // var x: u8 = 255;
    // x += 1; // Unchecked Illegal Behavior in ReleaseFast/ReleaseSmall modes.
    {
        // However this block has safety enabled, so safety checks happen here,
        // even in ReleaseFast and ReleaseSmall modes.
        @setRuntimeSafety(true);
        var x: u8 = 255;
        x += 1;

        {
            // The value can be overridden at any scope. So here integer overflow
            // would not be caught in any build mode.
            @setRuntimeSafety(false);
            // var x: u8 = 255;
            // x += 1; // Unchecked Illegal Behavior in all build modes.
        }
    }
}
```

## 7.4 Ship with safety on unless a profile says otherwise

TigerBeetle defaults to ReleaseSafe and its simulator refuses fast builds because they
disable assertions [[tigerbeetle-code#^f4]]:

```zig
// tigerbeetle build.zig:88 @ 0450c32
pub fn build(b: *std.Build) !void {
    const mode = b.standardOptimizeOption(.{ .preferred_optimize_mode = .ReleaseSafe });

// tigerbeetle src/vopr.zig:133 @ 0450c32
    // We do not support ReleaseFast or ReleaseSmall because they disable assertions.
    comptime assert(builtin.mode == .Debug or builtin.mode == .ReleaseSafe);
```

ZLS and River document `-Doptimize=ReleaseSafe` as the install command. Bun is the
counter-lesson: ReleaseFast removed the bounds checks that would have caught a real
off-by-one [[bun-in-rust#^f7]]. Loris Cro: disabling asserts hides wrong ones and later
code builds on them [[kristoff-fix-your-asserts#^f9]]. Ghostty does ship ReleaseFast,
relying on debug-build safety plus Valgrind, and reports it working
[[mitchellh-ghostty-gtk-rewrite#^f6]]. Opt out per hot scope with `@setRuntimeSafety`
once a profile shows the cost.

## 7.5 Where and how to assert

- **Arguments, invariants and results**, at the top and bottom of functions; Tiger
  Style asks for an average of two per function [[tigerbeetle-tiger-style#^f7]]:

```zig
// tigerbeetle src/vsr/replica.zig:647 @ 0450c32
        pub fn open(
            self: *Replica,
            parent_allocator: std.mem.Allocator,
            time: Time,
            storage: *Storage,
            message_pool: *MessagePool,
            options: OpenOptions,
        ) !void {
            assert(options.storage_size_limit <= constants.storage_size_limit_max);
            assert(options.storage_size_limit % constants.sector_size == 0);
            assert(options.random_nonce != 0);
            assert(options.release.value > 0);
            assert(options.release.value >= options.release_client_min.value);
            assert(options.pipeline_requests_limit >= 0);
            assert(options.pipeline_requests_limit <= constants.pipeline_request_queue_max);
            if (options.commit_stall_probability) |p| assert(p.numerator <= p.denominator);
```

  Measured density: TigerBeetle 3.7 per function overall, but 35% of functions have none
  and utilities sit at 0.3 to 0.8 [[tigerbeetle-code#^f42]]; ZLS ~6 and River ~12 per
  1000 lines; the std's InternPool 161 in 13k lines. Density follows subtle state, not a
  quota.

- **Pair assertions**: check a property on two paths (write then read, send then
  receive), so each side can be reasoned about alone [[tigerbeetle-blog-pair-assertions#^f2]].
- **Split compound asserts** so a failure says which; write implications as `if (a)
  assert(b)`; TigerBeetle's `maybe(c)` documents that a condition legitimately goes both
  ways [[tigerbeetle-tiger-style#^f9]], [[tigerbeetle-code#^f20]]:

```zig
// tigerbeetle src/stdx/stdx.zig:382 @ 0450c32
/// `maybe` is the dual of `assert`: it signals that condition is sometimes true
///  and sometimes false.
///
/// Currently we use it for documentation, but maybe one day we plug it into
/// coverage.
pub fn maybe(ok: bool) void {
    assert(ok or !ok);
}
```

- **Contracts with defer**: `assert(pre); defer assert(post);`. The post-condition caught
  unintended reentrancy in TigerBeetle's simulator [[matklad-defer-patterns#^f3]]:

```zig
// research/raw/matklad-defer-patterns.md:29 (TigerBeetle grid.zig)
  {
    assert(!grid.free_set.opened);
    defer assert(grid.free_set.opened);

    // Code to open the free set
  }
```

- **Assert state at callback entry** and in state machines: River asserts
  `window.state == .mapped` [[matklad-async-mutexes#^f4]].

## 7.6 Bounded loops

There is almost always an up-front bound, and a crash is easier to debug than a hang
[[matklad-lovely-syntax#^f7]]:

```zig
// research/raw/matklad-retry-loop-retry.md:75
  var retries_left = retry_count;
  const result = try for(0..retry_count + 1) {
      const err = if (action()) |ok| break ok else |err| err;
      if (!is_transient_error(err)) break err;

      if (retries_left == 0) break err;
      retries_left -= 1;
      sleep();
  } else @panic("runaway loop");
```

`while (true)` only for an event loop, and assert it. Even TigerBeetle's tooling scans
with `for (0..1024) |_| {...} else std.debug.panic(...)`.

## 7.7 Comptime assertions are executable comments

Relations between constants, struct sizes and target assumptions, checked every build
[[tigerbeetle-code#^f14]], [[zig-compiler-dod#^f5]], [[matklad-newtype-index#^f10]]:

```zig
// tigerbeetle src/constants.zig:44 @ 0450c32
comptime {
    // Invariant: to guarantee durability, a log entry from a previous checkpoint can be overwritten
    // only when there is a quorum of replicas at the next checkpoint.
    // [... 20 comment lines elided ...]
    assert(vsr_checkpoint_ops + lsm_compaction_ops + pipeline_prepare_queue_max * 2 <=
        journal_slot_count);
    assert(vsr_checkpoint_ops >= pipeline_prepare_queue_max);
    assert(vsr_checkpoint_ops >= lsm_compaction_ops);
    assert(vsr_checkpoint_ops % lsm_compaction_ops == 0);
}
```

```zig
// ziglang/zig lib/std/zig/Zir.zig:2521 @ 0.17.0
        // Make sure we don't accidentally add a field to make this union
        // bigger than expected. Note that in Debug builds, Zig is allowed
        // to insert a secret field for safety checks.
        comptime {
            if (builtin.mode != .debug and builtin.mode != .safe) {
                assert(@sizeOf(Data) == 8);
            }
        }
```

## 7.8 Two tiers: cheap checks always, integrity checks in debug

Ghostty's full page integrity checks made the terminal unusable, so they sit behind
`slow_runtime_safety` (debug only); debug-only fields are typed `if (cond) T else void`
and cost nothing in release [[ghostty-repo#^f26]], [[kristoff-comptime-sqlite#^f6]]:

```zig
// ghostty src/build_config.zig:60 @ 08a9518
pub const slow_runtime_safety = std.debug.runtime_safety and switch (builtin.mode) {
    .debug => true,
    .safe,
    .small,
    .fast,
    => false,
};

// ghostty src/terminal/page.zig:231 @ 08a9518
    pause_integrity_checks: if (build_options.slow_runtime_safety) usize else void =
        if (build_options.slow_runtime_safety) 0 else {},
```

TigerBeetle gates expensive checks with `-Dconfig_verify` (on in debug)
[[tigerbeetle-code#^f9]].

## 7.9 Every unreachable says why

On the same line, so the reader can check the claim; Roc enforces it with a build step
[[roc-zig-compiler#^f3]], [[zls-repo#^f19]]:

```zig
// roc src/check/dispatch_evidence.zig:68 @ 55a9d652
    pub fn stepKind(self: PathStep) Kind {
        return self.kindOrNull() orelse unreachable; // PathStep construction writes only Kind values, and artifact validation rejects any other discriminant
    }
```

TigerBeetle's "offensive programming": decoders of internal data return an optional, and
internal callers unwrap with `.?` so a bug crashes loudly [[tigerbeetle-blog-four-fuzzers#^f4]].

## 7.10 Assert cost in hot loops: measure

Ghostty found `std.debug.assert` calls not always removed in fast builds on 0.15.2,
costing 15-20% in hot loops, and forces an inline assert outside debug
[[ghostty-repo#^f25]]. Unverified on 0.17; measure before copying.

```zig
// ghostty src/quirks.zig:45 @ 08a9518
pub const inlineAssert = switch (builtin.mode) {
    // In debug builds we just use std.debug.assert because this
    // fixes up stack traces. `inline` causes broken stack traces. This
    // is probably a Zig compiler bug but until it is fixed we have to
    // do this for development sanity.
    .debug => std.debug.assert,

    .small, .safe, .fast => (struct {
        inline fn assert(ok: bool) void {
            if (!ok) unreachable;
        }
    }).assert,
};
```

## 7.11 Wrap footguns and ban the originals

`@memcpy` with overlapping slices is illegal; std int parsing accepts `000` and `-0`;
`io.random` silently falls back to a predictable seed on 0.16. TigerBeetle wraps each
in a strict version and bans the original in its lint [[tigerbeetle-code#^f19]],
[[tigerbeetle-code#^f26]]:

```zig
// tigerbeetle src/stdx/stdx.zig:1029 @ 0450c32 (Zig 0.16 std.Io)
/// Fills `buffer` with cryptographically secure random bytes from the OS.
///
/// Panics if the OS fails to provide entropy, like Zig 0.14's `std.crypto.random`. Unlike this,
/// `io.random` silently falls back to a predictable seed (pid, time, and an ASLR address).
pub fn crypto_random_bytes(io: std.Io, buffer: []u8) void {
    const cancel_protection = io.swapCancelProtection(.blocked);
    defer _ = io.swapCancelProtection(cancel_protection);

    io.randomSecure(buffer) catch |err| switch (err) {
        error.Canceled => unreachable,
        error.EntropyUnavailable => @panic("crypto_random_bytes: entropy unavailable"),
    };
}
```

Customise the std through root declarations, not forks: `pub const std_options:
std.Options = .{ ... }` and `pub const panic = std.debug.FullPanic(myPanic);`
[[zig-langref-017-b#^f86]].
