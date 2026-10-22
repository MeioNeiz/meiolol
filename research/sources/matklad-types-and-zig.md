---
title: Types and the Zig Programming Language (matklad, 2023-08-09)
url: https://matklad.github.io/2023/08/09/types-and-zig.html
kind: article
commit: 
for: [zig-comptime, zig-api-design]
looked: 2026-10-22
depth: docs (whole post)
relevance: medium
grade: B/strong
description: Zig types are nominal though anonymous, generics have no unification (methods close over type params), and signatures are explicit except inferred error sets
---
# Types and the Zig Programming Language (matklad, 2023-08-09)

Why: what Zig's type system implies for API shape. Zig 0.11 era; `@typeInfo(...).ErrorSet`
is the old tag name (now `.error_set`), otherwise current.

## Assessment

- Evidence: B. Expert, early in his Zig use (2023), examples compiled.
- Reasoning: strong. Compares with Rust and functional languages.
- Interests: none.
- Weigh: concepts hold; one example uses pre-0.12 type info names.

## Findings

- [zig/comptime] Struct types are anonymous but nominal: two identical `struct { f: i32 }`
  expressions are different types; name it with `const S = struct {...}`. ^f1
  > Zig has a nominal type system despite the fact that types lack names.
- [zig/comptime] Anonymous struct literals are structural and coerce to a named type. ^f2
  > In other words, Zig structs are anonymous and nominal, but anonymous structs are structural!
- [zig/comptime] No unification: generic functions take the type explicitly
  (`reverse(i32, &xs)`). ^f3
  > So, anytime there’s a generic function like `fn reverse(comptime T: type, xs: []T) void`, the call site has to pass the type in explicitly:
- [zig/api] [zig/comptime] Methods on a generic type have the type parameters in scope,
  so `slice.reverse()` needs no types; covers about 80% of uses. ^f4
  > when you call a method on a “generic type”, its type parameters are implicitly in scope, and don’t have to be specified.
- [zig/comptime] [zig/api] Signatures are always explicit: even `bytesAsSlice(comptime T,
  bytes: anytype)` returns a computed type `BytesAsSliceReturnType(T, @TypeOf(bytes))`,
  not anytype. ^f5
  > Note how the return type is not `anytype`, but the actual, real thing.
- [zig/errors] [zig/comptime] Inferred error sets (`!T`) are the exception: checking the
  caller needs the callee's body. ^f6
  > But its not perfect, a genuine leakage happens with inferred error types (`!T` syntax).

## Read

- Whole post.

## Not read

- ziggit.dev discussion thread (linked): lead, low priority.
