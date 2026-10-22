---
title: Zig's Lovely Syntax (matklad, 2025-08-09)
url: https://matklad.github.io/2025/08/09/zigs-lovely-syntax.html
kind: article
commit: 
for: [zig-style, zig-api-design, zig-comptime]
looked: 2026-10-22
depth: docs (whole post)
relevance: high
grade: B/strong
description: Tour of Zig syntax decisions and the idioms they enable: greppable field writes, bounded loops, options structs, result location semantics, comptime closures
---
# Zig's Lovely Syntax (matklad, 2025-08-09)

Why: idioms that follow from Zig's syntax. Zig 0.14/0.15 era (decl literals `.init(gpa)`,
unmanaged ArrayList with `deinit(gpa)`); current for 0.17. `@coerceTo` in the post is
pseudo-code, not a builtin.

## Assessment

- Evidence: B. Expert with daily Zig use at TigerBeetle; code from TigerBeetle.
- Reasoning: strong. Each choice compared with Rust, C, Kotlin; ends with the one form
  he dislikes.
- Interests: none.
- Weigh: mostly descriptive; the actionable idioms are the bounded loop, options
  structs, grep for `.x =`, and avoiding while-with-increment.

## Findings

- [zig/style] Integer literals are `comptime_int` coerced on assignment, not inferred; so
  `var x = 92;` needs an explicit type. ^f1
  > To emphasize, this is _not_ type inference, this is implicit comptime coercion.
- [zig/style] `\\` multiline strings dodge indentation problems and lex line by line. ^f2
  > Unlike most other languages, Zig can be correctly lexed in a line-by-line manner.
- [zig/style] `.x = 1` in literals matches `obj.x = 1`, so grepping `.x =` finds every
  write of a field, which is what data flow needs. ^f3
  > This means that grepping for `".x ="` gives you _all_ instances where a field is written to.
- [zig/style] Labeled block `blk: { ... break :blk value; }` yields a value; blocks are
  otherwise void. ^f4
  > If you need a block that yields a value, Zig supports a general syntax for breaking out of a labeled block:
- [zig/style] One-line `if (a) b else c` is fine because zig fmt is part of the compiler
  and catches formatting that masks bugs (e.g. `1 -2` is an error). ^f5
  > formatting errors that can mask bugs are caught during compilation
- [zig/style] [zig/comptime] Loops are expressions with `else`: a comptime search
  `for (.{ u8, u16, ... }) |W| { if (...) break W; } else unreachable`. ^f6
  > if (@bitSizeOf(W) >= bitset_capacity) break W;
- [zig/safety] He writes "infinite" loops as `for (0..safety_bound) |_| {} else
  @panic("loop safety counter exceeded");`, because there is almost always a bound and
  crashes debug easier than hangs. ^f7
  > } else @panic("loop safety counter exceeded");
  > Almost always there is an up-front bound for the number of iterations until the break, and its worth asserting this bound, because debugging crashes is easier than debugging hangs.
- [zig/style] Zig forbids shadowing, has no prelude, no glob imports; `x.foo()` is
  always a method declared on x's type. ^f8
  > if you see `x.foo()`, that `foo` is guaranteed to be a boring method declared on `x` type
- [zig/comptime] [zig/api] Generic args are never inferred, but comptime closures keep the
  annotation burden low: `ArrayListType(u32)` once, then methods close over T. ^f9
  > Generic parameters are never inferred
  > in real code, 90% of functions are happiest as (non-virtual) methods
- [zig/api] Decl literal usage: `var xs: ArrayListType(u32) = .init(gpa); defer
  xs.deinit(gpa);`. ^f10
  > var xs: ArrayListType(u32) = .init(gpa);
- [zig/comptime] Result location semantics: type and result location flow down the
  expression tree; `.whatever` is shorthand for `@ResultType().whatever`. ^f11
  > In Zig, `.whatever` is a shorthand for `@ResultType().whatever`.
- [zig/api] Options struct with defaults gives named and default arguments for free:
  `fn exec(argv, options: struct { working_directory: ?[]const u8 = null })`, called
  `exec(&.{"git","status"}, .{})`; he uses them liberally. ^f12
  > In particular, you get named and default arguments for free:
  > But they are free in Zig, so I use them liberally.
- [zig/style] Built-ins split casts into named variants (`@intCast`, `@ptrCast`, ...)
  instead of one overloaded cast. ^f13
  > There’s no need to overload casting when you can give each variant a name.
- [zig/style] He dislikes `while (i < 10) : (i += 1)`: control flow out of source order and
  a sigil; `for (0..10) |i|` makes it redundant. ^f14
  > It has `for(0..10) |i|` form now, so I am tempted to call the while-with-increment redundant.
- [zig/style] `defer increment` inside a while body is not equivalent: return, break or
  try run the increment one extra time. ^f15
  > if `body` contains a `return`, `break` or `try`, the `defer` version would run the `increment` one extra time

## Read

- Whole post.

## Not read

- Linked "Rust's Ugly Syntax": Rust.
