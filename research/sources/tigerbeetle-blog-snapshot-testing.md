---
title: Snapshot Testing For the Masses (TigerBeetle blog, matklad, 2024)
url: https://tigerbeetle.com/blog/2024-05-14-snapshot-testing-for-the-masses
kind: article
commit:
for: [zig-testing]
looked: 2026-10-22
depth: docs (whole post)
relevance: high
grade: A/strong
description: building a self-updating snapshot test library in Zig from @src() and multiline string literals, as TigerBeetle's snaptest.zig
---
# Snapshot Testing For the Masses (TigerBeetle blog, matklad, 2024)

Why: the design behind `stdx/testing/snaptest.zig`, a pattern meiolol could copy for
page and stats output tests.

## Assessment

- Evidence: A. Describes the library in use across TigerBeetle (tidy, flags, REPL,
  trace tests); current code at [[tigerbeetle-code#^f34]].
- Reasoning: strong. Explains API choice (value, not macro), update policy, pitfalls
  (line endings, several updates, file system access).
- Interests: none.
- Weigh: code snippets use 2024 APIs: `std.ArrayList(u8).init`, `std.json.stringify`,
  `std.process.hasEnvVarConstant`. Stale for 0.17; the 0.16 file uses
  `std.testing.environ`, `std.Io.Writer.Allocating`, `std.zon.stringify`.

## Findings

- [zig/test] Why snapshots: they force readable text dumps of domain objects, keep
  tests from freezing the code, and focus tests on data in and out. ^f1
  > Snapshots require that domain objects have rich and readable textual representations.
  > Snapshot tests are easily adaptable to changes in requirements.
- [zig/test] [zig/api] The primitive is a value, not a macro: a string literal plus its
  `SourceLocation`, passed to ordinary check functions. ^f2
  > as soon as something is a macro, the only way to program it is with another macro.
  > The secret sauce here is `SourceLocation`.
- [zig/test] The caller writes `snap(@src(), \\...)`, which Zig makes cheap. ^f3
  > But in Zig, the caller has to write this exact pattern, which actually isn’t all that bad!
- [zig/test] Tests become `check(input, snap(...))`: a helper that serialises the
  result and diffs it. ^f4
  > The high order bit: because `Snapshot` is a first-class value, we can pass it around!
- [zig/test] Update on opt-in (env var or `.update()`), and touch files only when the
  test would fail anyway. ^f5
  > you should touch the file system only when the test would fail otherwise.
- [zig/test] Windows `\r\n` breaks comparison; fix with `.gitattributes`. ^f6
  > * text=auto eol=lf
- [zig/test] Volatile fields are skipped with `<snap:ignore>`. ^f7
  > The magic is `<snap:ignore>` — this is a special string recognized by the library.
- [zig/test] A useful library fits in under 500 lines. ^f8
  > A minimalist, but useful snapshot testing library can be implemented in less than 500 lines of code!

## Read

- Whole post.
