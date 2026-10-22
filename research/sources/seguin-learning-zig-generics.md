---
title: Learning Zig - Generics (Karl Seguin)
url: https://www.openmymind.net/learning_zig/generics/
kind: book
commit:
for: [zig-comptime]
looked: 2026-10-22
depth: docs (whole chapter)
relevance: low
grade: B/fair
description: Chapter on functions returning types, comptime type parameters and @This()
---
# Learning Zig - Generics (Karl Seguin)

Why: the basic generic container idiom.

## Assessment

- Evidence: B. Widely read intro; revised for 0.16.
- Reasoning: fair. Mechanics, little on when not to be generic.
- Interests: none known.
- Weigh: basics only; `Self = @This()` is common, but see ziggit notes on naming the type.

## Findings

- [zig/comptime] Generics are ordinary functions taking `comptime T: type` and returning a struct type; nothing special-cased. ^f1
  > With Zig, generics are less of a specific feature and more of an expression of what the language is capable of.
- [zig/comptime] The same arguments give the same type: instantiations are memoised. ^f2
  > If we use `List(u32)` again, the compiler will re-use the type it previous created.
- [zig/style] Inside the returned struct, `const Self = @This();` names the type; PascalCase because it holds a type. ^f3
  > `Self` isn't a special name, it's just a variable, and it's PascalCase because its value is a `type`.

## Read

- Whole chapter.
