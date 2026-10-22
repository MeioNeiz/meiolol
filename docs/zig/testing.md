# 11. Testing

## 11.1 Tests beside the code, leak-checked

Tests live at the bottom of the file they test, use `std.testing.allocator` (fails the
test on leaks, double and invalid frees) and `std.testing.io`
[[zig-std-containers#^f16]], [[zig-016-release-notes#^f4]]. `expectEqual(expected,
actual)`: peer type resolution makes casts unnecessary [[zig-std-testing#^f1]],
[[zig-std-testing#^f2]]. Prefer specific helpers for their messages; skip with
`error.SkipZigTest` [[zig-langref-017-a#^f26]], [[zig-langref-017-a#^f29]].

## 11.2 Make sure tests run

Zig collects tests lazily: only files that get analysed contribute, and
`refAllDecls(@This())` is one level and pub-only. An unreferenced file's tests are
silently skipped [[zig-langref-017-b#^f85]], [[roc-zig-compiler#^f6]]. Wire every file
from the root:

```zig
// ziglang/zig lib/std/json.zig:131 @ 0.17.0
test {
    _ = @import("json/test.zig");
    _ = Scanner;
    _ = @import("json/dynamic.zig");
    _ = @import("json/hashmap.zig");
    _ = @import("json/static.zig");
    _ = Stringify;
    _ = @import("json/JSONTestSuite_test.zig");
}
```

Roc checks the wiring with a CI tool; TigerBeetle's lint flags files nothing imports
[[tigerbeetle-tidy#^f14]].

## 11.3 Test the error paths

`errdefer` runs only on error, so ordinary tests never exercise it; Mitchell calls error
cleanup one of the most error-prone parts of Zig [[mitchellh-tripwire#^f1]]. Two tools:

- `std.testing.checkAllAllocationFailures` reruns a test failing each allocation in
  turn and, on `testing.allocator`, catches leaks and double frees per path. It needs a
  deterministic allocation count and runs N+1 times [[liptak-check-all-allocation-failures#^f5]],
  [[zig-std-testing#^f6]]:

```zig
// ziglang/zig lib/std/testing.zig:1119 @ 0.17.0 (doc comment)
/// fn testImpl(allocator: std.mem.Allocator, length: usize) !void {
///     var foo = try allocator.alloc(u8, length);
///     var bar = try allocator.alloc(u8, length);
///
///     allocator.free(foo);
///     allocator.free(bar);
/// }
///
/// test {
///     const length: usize = 10;
///     const allocator = std.testing.allocator;
///     try std.testing.checkAllAllocationFailures(allocator, testImpl, .{length});
/// }
```

- Fault injection for errors other than OOM: Ghostty's tripwire marks fail points per
  function, zero cost outside tests; its first use found about six real bugs
  [[mitchellh-tripwire#^f2]], [[ghostty-repo#^f66]]:

```zig
// ghostty src/terminal/PageList.zig:588, :9673 @ 08a9518
const init_tw = tripwire.module(enum {
    init_memory_pool,
    init_pages,
    viewport_pin,
    viewport_pin_track,
}, init);
...
test "PageList init error" {
    // Test every failure point in `init` and ensure that we don't
    // leak memory (testing.allocator verifies) since we're exiting early.
    for (std.meta.tags(init_tw.FailPoint)) |tag| {
        const tw = init_tw;
        defer tw.end(.reset) catch unreachable;
        tw.errorAlways(tag, error.OutOfMemory);
        try std.testing.expectError(
            error.OutOfMemory,
            init(std.testing.allocator, .{
                .cols = 80,
                .rows = 24,
            }),
        );
    }
```

ZLS can also build the real binary with an allocator that fails 1 in N calls
[[zls-repo#^f9]]. Bun's author traces its leaks to error paths [[bun-in-rust#^f4]].

## 11.4 Data-driven tests through one check function

API changes then touch one place; adding a case is one literal; failures show text diffs
[[matklad-how-to-test#^f1]], [[zls-repo#^f31]]:

```zig
// zls tests/lsp_features/hover.zig:11 @ 82ba5351
test "primitive" {
    try testHover(
        \\const foo = bool<cursor>;
    ,
        \\```zig
        \\bool
        \\```
        \\```zig
        \\(type)
        \\```
    );
```

Keep computation sans IO so tests stay fast; IO, not code volume, makes tests slow
[[matklad-how-to-test#^f4]].

## 11.5 Snapshot tests

Expectations that update themselves make software cheap to change. TigerBeetle's
`snap(@src(), ...)` is a string literal that knows where it lives and rewrites itself
under `SNAP_UPDATE=1`; under 500 lines, no dependency
[[tigerbeetle-blog-snapshot-testing#^f2]], [[matklad-snapshot-testing#^f1]]:

```zig
// research/raw/matklad-snapshot-testing.md:29 (TigerBeetle snaptest.zig API)
test "basic arithmetics" {
    const result = 2 + 2;

    try snap(@src(),
        \\2 + 2 = 5
    ).diff_fmt("2 + 2 = {}", .{result});
}
```

For file outputs, Loris Cro regenerates committed files in `zig build test` and fails on
`git diff --exit-code` [[kristoff-snapshot-testing#^f3]]. matklad's order: fuzz first; if
you can't fuzz, snapshot test; keep a few example tests as smoke checks
[[matklad-snapshot-testing#^f7]].

## 11.6 Fuzzing

The core team: "write one fuzz test and then delete 99 unit tests"; they fuzz their own
tokenizer, parser (against an oracle grammar) and zig fmt [[zig-talk-roadmap-2026#^f14]],
[[zig-017-release-notes#^f15]]. 0.16 replaced byte-slice fuzz inputs with
`*std.testing.Smith`, which generates typed values [[zig-016-release-notes#^f41]]. The
std's own Deque fuzz test drives the Deque and an ArrayList with the same weighted
actions and expects identical results [[zig-std-testing#^f13]]:

```zig
// ziglang/zig lib/std/deque.zig:641 @ 0.17.0
    while (!smith.eosWeightedSimple(15, 1)) {
        const baseline = testing.Smith.baselineWeights(Action);
        const grow_weight: testing.Smith.Weight = .value(Action, .grow, 3);
        switch (smith.valueWeighted(Action, baseline ++ .{grow_weight})) {
            .push_back => {
                const item = smith.value(u32);
                try testing.expectEqual(
                    l.appendBounded(item),
                    q.pushBackBounded(item),
                );
            },
```

Practice from the respected projects:

- fuzz against an oracle: a slow simple version, or a model [[matklad-finding-bugs#^f2]]
- keep found crashes as a corpus via `@embedFile`, or a base64 replay test
  [[zig-016-release-notes#^f42]], [[superhtml-repo#^f22]]
- TigerBeetle doesn't use the built-in fuzzer: its fuzzers are plain seeded programs,
  one dispatcher, a CI smoke mode with a fixed seed and a time budget, and a canary that
  fails on purpose to prove the harness reports failure [[tigerbeetle-code#^f39]],
  [[tigerbeetle-blog-four-fuzzers#^f8]]. Ghostty uses AFL++ with a resettable bump
  allocator [[ghostty-repo#^f69]]. This repo saw `zig build --fuzz` exit 0 on a crash,
  so check the fuzz log
- distrust sizes from input; fuzz with an allocator wrapper that fails oversized
  allocations [[liptak-fuzz-allocators#^f2]]

## 11.7 Random tests, swarm weights, small inputs

- seed from `std.testing.random_seed` so every run explores new cases yet a failure
  replays; run statistical asserts once with a fixed seed too
  [[tigerbeetle-blog-four-fuzzers#^f6]]
- swarm testing: sample action weights per run, some zero, to reach states uniform
  choice never does; drive actions from `std.meta.DeclEnum` so each new public method
  forces a test arm [[tigerbeetle-blog-swarm-testing#^f2]]
- a finite-entropy RNG gives free test minimisation: search the smallest failing entropy
  size [[matklad-test-minimization#^f1]]
- exhaustive enumeration of small inputs, smallest first, finds minimal failures
  [[matklad-generate-all#^f1]]
- shrink every limit for tests (TigerBeetle's `test_min` config: tiny WAL, block size,
  queues) so edge cases are a few operations away [[tigerbeetle-code#^f15]]

## 11.8 Test hygiene

- no stdout in tests: the build runner talks to the test runner over it
  [[zig-learn-build-system#^f13]]
- since 0.16 any stderr output marks a run failed; Ghostty sets
  `std.testing.log_level = .err` at the root, TigerBeetle downgrades `log.err` to warn
  in test builds to test error paths [[ghostty-repo#^f64]], [[tigerbeetle-code#^f21]]
- set `--test-timeout`; it is wall-clock, so a loaded box can trip it
  [[zig-016-release-notes#^f36]]
- coverage marks tie a branch to the test that explains it
  [[tigerbeetle-code#^f36]]
- benchmarks and lints can be tests: the full suite runs them small and silent, a filter
  runs them big [[matklad-mechanical-habits#^f6]], [[tigerbeetle-tidy#^f1]]

Loris Cro's weighting: unit tests have momentum and couple to internals; asserts plus
fuzzing are worth more [[kristoff-talk-better-software#^f3]].
