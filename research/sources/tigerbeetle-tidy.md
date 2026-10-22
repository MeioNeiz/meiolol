---
title: TigerBeetle src/tidy.zig (style lint as a Zig test), last public version
url: https://raw.githubusercontent.com/tigerbeetle/tigerbeetle/24d92bff033453dcc757adfcd9aa14655d1b1734/src/tidy.zig
kind: project
commit: 24d92bff033453dcc757adfcd9aa14655d1b1734
for: [zig-style, zig-testing, zig-build, zig-good-practice]
looked: 2026-10-22
depth: code (src/tidy.zig, all 1539 lines)
relevance: high
grade: A/strong
description: TigerBeetle's lint, a Zig test over every git-tracked file: line length, banned APIs, Type suffix, dead code and files, function length ratchet, defer newlines, precedence, repo hygiene
---
# TigerBeetle src/tidy.zig (style lint as a Zig test), last public version

Why: how much of Tiger Style is enforced by a machine, and how a Zig project can lint
itself without external tools.

## Assessment

- Evidence: A. Ran in TigerBeetle CI for years (CHANGELOG mentions function length
  limits and unused-import checks); same project signals as [[tigerbeetle-code]].
- Version: this is the file at 24d92bf (2026-09-23), the parent of commit 2f45ef6
  "tidy: move" ("We now have a separate place for such tooling"), which removed it from
  the public repo days before the 0.16 upgrade. So the code is Zig 0.14.1 (e.g.
  `std.ArrayList(...).init(allocator)`, `std.fs.cwd().readFile`, `data.lhs`), stale
  for 0.17 APIs; the checks themselves are what matter.
- Reasoning: strong. Each check comments why; heuristics state their false-negative
  direction; each has a snapshot test.
- Interests: none.
- Weigh: the checks port to any Zig repo. Several bans encode TigerBeetle-only
  wrappers (stdx); the language footgun bans are general.

## Findings

- [zig/test] [zig/style] Lint is an ordinary Zig `test "tidy"` that lists files with
  `git ls-files`, reads each once into a fixed 1 MiB buffer, and runs all checks
  streaming; it ran with `zig build test -- tidy`. `src/tidy.zig` ^f1
  > // NB: all checks are intentionally implemented in a streaming fashion,
  > const files = try shell.exec_stdout("git ls-files -z", .{});
- [zig/style] Line length: over 100 codepoints is an error, except lines with a URL
  and multiline string literals whose value fits; a few named snapshot tables are
  exempt. `src/tidy.zig` ^f2
  > if (line_length <= 100) return;
  > // For multiline strings, we care that the _result_ fits 100 characters,
- [zig/style] [zig/errors] Ban list (string match): std types replaced by stdx
  (`std.BoundedArray`, `StaticBitSet`, `std.time.Instant`), `@memcpy(` for
  `stdx.copy_disjoint`, std int parsing and PRNG range functions; library and
  language footguns. `src/tidy.zig` ^f3
  > .{ "@memcpy(", "stdx.copy_disjoint" },
  > .{ "posix.send(", "posix.sendto to avoid connection race condition" },
- [zig/errors] Comparing errors with `==`/`!=` is banned: use `switch`, because
  `err == error.Foo` silently upcasts to `anyerror` and won't catch a misspelt or
  removed error. `src/tidy.zig` ^f4
  > .{ "== error.", "switch to avoid silent anyerror upcast" },
- [zig/style] Also banned: `debug.assert(` (import `assert` unqualified),
  `Self = @This()` (use the real type name), `!comptime`, `usingnamespace`; leftover
  `FIXME` and `dbg(` fail the check, FIXME being the agreed "fix before merge"
  marker. `src/tidy.zig` ^f5
  > .{ "Self = @This()", "proper type name" },
  > .{ "debug.assert(", "unqualified assert" },
  > // Do use FIXME comments proactively while iterating on the code when you want to make sure
- [zig/style] Function length is a ratchet, not a hard cap: only functions of 71 or 72
  lines fail, so small functions can't creep past 70 while long old ones are left
  alone. `src/tidy.zig` ^f6
  > // We ratchet 70-lines-per-function TigerStyle rule from the bottom up. Some functions want
  > .min = 70, // NB: both are exclusive, so red zone is intentionally empty to start!
- [zig/style] Functions in CamelCase (they return a type) must end in `Type`. `src/tidy.zig` ^f7
  > /// All functions using the `CamelCase` naming convention return a type,
  > /// so we enforce that the function name also ends with the `Type` suffix.
- [zig/style] Dead code: a non-`pub` const or fn whose identifier appears once in its
  file is an error (lexer-based, may miss some, never wrong). `src/tidy.zig` ^f8
  > /// This is a one-side heuristic: there might be false negatives, but no false positives.
- [zig/build] Dead files: because Zig compiles lazily, a file nothing imports is never
  checked; tidy greps `@import("x.zig")` and flags never-imported files except listed
  entry points. `src/tidy.zig` ^f9
  > // Zig's lazy compilation model makes it too easy to forget to include a file into the build --- if
  > // nothing imports a file, compiler just doesn't see it and can't flag it as unused.
- [zig/style] Mixing bitwise and arithmetic operators without parentheses is an error
  (`1 + foo << 3`). `src/tidy.zig` ^f10
  > ambiguous operator precedence, add parenthesis
- [zig/style] [zig/memory] A `defer` must be followed by a blank line (or another
  defer/errdefer or a closing brace), enforcing Tiger Style's grouping of a resource
  with its cleanup. `src/tidy.zig` ^f11
  > defer must be followed by a blank line
- [zig/build] Repo hygiene tests: no blob over 256 KiB in history (three named
  exceptions), only expected executable bits and file extensions, changelog line
  length and no `?si=` tracking params. `src/tidy.zig` ^f12
  > test "tidy no large blobs" {
  > if (std.mem.indexOf(u8, line, "?si=") != null) {
- [zig/style] Policy: the last 32 commits are scanned for agent names (aider, claude,
  codex, copilot, cursor, gemini) in author and trailers; any hit fails with "does not
  allow LLM contributions". `src/tidy.zig` ^f13
  > "{s} {s}: TigerBeetle does not allow LLM contributions.\n",
- [zig/test] Every check has a `test check_name { ... snap(@src(), ...) }` showing
  input and exact error output; `test` names can be the function identifier
  (`test tidy_banned`) so they follow renames. `src/tidy.zig` ^f14
  > test tidy_banned {
  > \\banned.zig:2: error: @memcpy( is banned, use stdx.copy_disjoint
- [zig/style] Checked, not there: no check for assertions per function, comment
  style, `usize`, units-last naming, recursion or allocation after init: those rules
  rest on review (allocation also on `StaticAllocator` at runtime). ^f15

## Read

- `src/tidy.zig`: all.

## Not read

- Where tidy lives now ("a separate place for such tooling"); not public at 0450c32.
