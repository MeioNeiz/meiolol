---
status: answered
parent: zig-good-practice
priority: soon
area: code
tags: [zig/style]
description: How do the Zig docs and respected projects name, lay out, format and comment Zig code?
---
# How do the Zig docs and respected projects name, lay out, format and comment Zig code?

Feeds: docs/zig/README.md (the Zig practice guide, split by topic), then applying it to the repo

## Answer

The official Style Guide plus `zig fmt` is the base every respected project uses, and
most add very few rules on top (C1, C9). Names: snake_case for namespaces, files without
fields and variables; TitleCase for types, type-returning functions and files with
fields; camelCase for other functions; acronyms are words (C2). Avoid redundant words
(Value, Data, Manager, utils) and repeating the namespace path (C3). A file with fields is
a type named by `const Name = @This();`; `Self` is for anonymous structs returned by type
functions; receivers are short type-derived names, not `self` (C4, C5). Doc comments say
what the name doesn't: ownership, invalidation, complexity, asserts, in fixed phrases
(C6). TigerBeetle adds units and qualifiers last, an index/count/offset/size vocabulary,
a `Type` suffix on type functions, 100 columns and a function-length ratchet (C7, C8);
snake_case functions there and in matklad's code depart from the std (C10). Line length
is taste (100 std/TigerBeetle, ~90 here); steer `zig fmt` with trailing commas (C11).

## Claims

- C1: The official Style Guide and zig fmt are the base; mature projects add few rules on top. for: [[zig-langref-017-b#^f102]], [[river-repo#^f2]], [[river-repo#^f3]], [[zls-repo#^f39]]
- C2: Naming: namespaces and variables snake_case, types and type functions TitleCase, other functions camelCase, acronyms as words; files with fields TitleCase. for: [[zig-langref-017-b#^f103]], [[zig-langref-017-b#^f104]], [[zig-langref-017-b#^f105]], [[seguin-learning-zig-style-guide#^f1]]
- C3: No redundant words or namespace repetition in names; no utils or misc modules. for: [[zig-langref-017-b#^f97]], [[zig-langref-017-b#^f98]], [[zig-langref-017-b#^f99]]
- C4: A file with fields names itself with `const Name = @This();`; `Self` only in anonymous type-function structs. for: [[zig-langref-017-b#^f84]], [[zig-compiler-dod#^f24]], [[ghostty-repo#^f1]], [[river-repo#^f6]], [[ziggit-self-and-this#^f1]] against: [[seguin-learning-zig-generics#^f3]]
- C5: Receivers are short type-derived names (`w`, `ip`, `tree`) rather than `self`. for: [[zig-compiler-dod#^f23]], [[ziggit-self-and-this#^f3]]
- C6: Doc comments state ownership, pointer invalidation, complexity and asserts in fixed phrases; leave out what the name says. for: [[zig-std-containers#^f8]], [[zig-std-containers#^f9]], [[zig-langref-017-b#^f106]], [[zig-langref-017-b#^f107]], [[zig-langref-017-a#^f7]]
- C7: Units and qualifiers go last (`latency_ms_max`); index, count, offset and size have fixed meanings. for: [[tigerbeetle-tiger-style#^f28]], [[tigerbeetle-blog-index-count-offset-size#^f1]], [[tigerbeetle-code#^f44]]
- C8: Function length is held by a ratchet, not a hard cap. for: [[tigerbeetle-tidy#^f6]], [[tigerbeetle-code#^f43]] against: [[tigerbeetle-tiger-style#^f15]]
- C9: What matters is enforced mechanically, by lints written in Zig over std.zig.Ast or as a test. for: [[tigerbeetle-tidy#^f1]], [[roc-zig-compiler#^f10]], [[roc-zig-compiler#^f7]], [[bun-in-rust#^f12]]
- C10: TigerBeetle and matklad use snake_case functions and a `Type` suffix, against the std convention. for: [[tigerbeetle-tidy#^f5]], [[tigerbeetle-tidy#^f7]]
- C11: Formatting is steered with trailing commas; lists over two items one per line. for: [[matklad-steering-zig-fmt#^f1]], [[zig-langref-017-b#^f102]]
- C12: One `std.log.scoped` per file named after the module. for: [[ghostty-repo#^f7]], [[zls-repo#^f21]], [[river-repo#^f17]]
- C13: Prefer const and fresh names; no shadowing is enforced so a name means one thing in scope. for: [[zig-langref-017-a#^f18]], [[zig-langref-017-a#^f35]], [[ak-openzfs-bug-zig#^f2]]

## Disagreements

- `Self` vs type name: Seguin teaches `Self` (B); std 0.17 (128 files vs 3), Ghostty,
  TigerBeetle (tidy bans it) and ziggit regulars use the type name. Type name wins.
- Function casing: std camelCase vs TigerBeetle/matklad snake_case. Both consistent;
  meiolol already uses camelCase (1657 vs 44), so std.
- Comments as full sentences (Tiger Style) vs terse (this repo's CLAUDE.md); both agree
  on why-not-what.

## Open

- Import placement (top in ZLS, River, Ghostty; bottom in zig-clap, Bun): no source
  argues for either beyond consistency
- Whether a mechanical lint (tidy) pays off for a one-developer repo
