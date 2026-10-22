---
status: answered
parent: zig-good-practice
priority: soon
area: code
tags: [zig/comptime]
description: When and how should Zig code use comptime: generics, type functions, anytype, reflection, and where do respected projects stop?
---
# When and how should Zig code use comptime: generics, type functions, anytype, reflection, and where do respected projects stop?

Feeds: docs/zig/README.md (the Zig practice guide, split by topic), then applying it to the repo

## Answer

Comptime is partial evaluation: generics are comptime parameters and functions returning
`type`, untaken comptime branches are not analysed, and it is for guarantees, not speed
(C1, C2). Respected applications keep it sparse, in a few generic helpers (C3); overuse
costs compile time and binary size (Bun) and the core team built `--time-report` to audit
it (C4). Good comptime APIs fail with a located `@compileError` and often have a runtime
twin (C5). Prefer `comptime T: type` to `anytype` where the type shapes the signature;
anytype is fine for obvious duck-typed internal helpers (C6). `inline else` beats `inline
for` over fields; inline prongs with `comptime unreachable` give checked partial matches;
generated subset unions keep switches exhaustive (C7, C8). Select backends at comptime
from build options; mind the function-boundary gotcha and build every option in CI (C9).
0.17 reflection is struct-of-arrays and types are built with `@Int`, `@Struct`; detect
features with a `{}` sentinel, not `@hasDecl` (C10, C11). Codegen needing IO belongs in
build.zig (C12).

## Claims

- C1: Generics are comptime parameters and type-returning functions; untaken comptime branches are not analysed. for: [[zig-langref-017-b#^f39]], [[zig-langref-017-b#^f40]], [[zig-langref-017-b#^f45]], [[matklad-comptime-wont-do#^f3]]
- C2: Comptime is for guarantees, not optimisation. for: [[zig-langref-017-b#^f41]]
- C3: Applications keep comptime in a few generic helpers. for: [[zls-repo#^f38]], [[river-repo#^f25]], [[superhtml-repo#^f25]], [[mitchellh-ghostty-and-useful-zig-patterns#^f9]]
- C4: Comptime overuse costs compile time and binary size; audit it with --time-report. for: [[bun-in-rust#^f9]], [[ak-bun-rust-rewrite#^f4]], [[tigerbeetle-blog-copy-hunting#^f4]]
- C5: Good comptime APIs reject misuse with a located @compileError. for: [[zig-std-containers#^f22]], [[zig-clap-repo#^f2]], [[kristoff-comptime-sqlite#^f3]], [[ghostty-repo#^f45]]
- C6: Prefer `comptime T: type` to anytype when the type shapes the signature. for: [[ziggit-generic-anytype#^f2]], [[ziggit-generic-anytype#^f3]] against: [[matklad-comptime-orm#^f14]]
- C7: `inline else` is the checked way to generate per-variant code, preferred to inline for over fields. for: [[zig-langref-017-a#^f108]], [[zig-langref-017-a#^f107]]
- C8: Inline prongs with `comptime unreachable` and generated subset unions keep switches exhaustive. for: [[matklad-partial-enums#^f2]], [[mitchellh-zig-comptime-tagged-union-subset#^f2]], [[ghostty-repo#^f96]]
- C9: Backends are chosen at comptime from build options; comptime if does not cross a plain call. for: [[ghostty-repo#^f38]], [[mitchellh-zig-comptime-conditional-disable#^f5]], [[mitchellh-zig-comptime-conditional-disable#^f7]]
- C10: 0.17 reflection is struct-of-arrays; types are built with @Int, @Struct, @Enum. for: [[zig-017-release-notes#^f3]], [[zig-016-release-notes#^f26]], [[zig-langref-017-a#^f88]], [[zig-langref-017-b#^f50]]
- C11: Feature detection uses a `{}` sentinel and builtin.target, not @hasDecl. for: [[zig-015-release-notes#^f3]], [[zig-langref-017-b#^f47]], [[zig-017-release-notes#^f19]]
- C12: Comptime cannot do IO or add methods; IO-needing codegen goes through build.zig. for: [[matklad-comptime-wont-do#^f8]], [[matklad-comptime-wont-do#^f9]], [[kristoff-comptime-sqlite#^f7]]
- C13: In reflection, pass fields as std.meta.FieldEnum(T), not strings. for: [[matklad-comptime-orm#^f9]]
- C14: Comptime-built data fills a local comptime var then copies to a const. for: [[zig-012-release-notes#^f5]], [[zig-012-release-notes#^f6]]
- C15: inline loops and inline fn only for comptime semantics or a measured win. for: [[zig-langref-017-a#^f112]], [[zig-langref-017-a#^f122]]

## Disagreements

- anytype: the ziggit doc and code-smell thread (C) prefer `comptime T`; matklad uses
  anytype freely for comptime duck typing (B). Settle by role: avoid on public runtime
  APIs, fine in internal comptime helpers.
- Reflection: matklad teaches a full comptime ORM then says avoid reflection; Ghostty
  uses it for config. Use it for wide repetitive surfaces only.

## Open

- Compile-time cost of meiolol's own comptime (run --time-report)
