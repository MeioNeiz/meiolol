---
title: Zig's new declaration literals (Karl Seguin, 2024)
url: https://www.openmymind.net/Zigs-New-Declaration-Literals/
kind: article
commit:
for: [zig-api-design, zig-style]
looked: 2026-10-22
depth: docs (whole post)
relevance: medium
grade: B/fair
description: Decl literals generalise enum literals: .init and named presets; trade-off against .{} field overrides
---
# Zig's new declaration literals (Karl Seguin, 2024)

Why: how and when to offer `.init`, `.empty` and presets.

## Assessment

- Evidence: B. Practitioner, Nov 2024 (pre-0.14 dev). Feature shipped in 0.14.
- Reasoning: fair; balanced, notes "only one obvious way" tension.
- Interests: none known.
- Weigh: misses that decl literals also call functions (`.init(gpa)`), which is how most
  0.14+ std code uses them.

## Findings

- [zig/api] A decl literal `.init` resolves to a declaration on the result type, as enum literals do for tags. ^f1
  > var gpa: std.heap.GeneralPurposeAllocator(.{}) = .init;
- [zig/api] Several named presets can live on one type. ^f2
  > One benefit of this approach is that we can have multiple declarations. This allows us to have groups of default values behind a meaningful label
- [zig/api] They shine with generic types, avoiding repeating the long type name. ^f3
  > But that's a lot more messy with generics, which is one area where declarations literals really shines:
- [zig/api] Field defaults with `.{}` let callers override one field; with `.init` they must assign afterwards. Decl literals help keep invariants that per-field defaults can break. ^f4
  > Furthermore, using the `.{}` syntax gives the caller the flexibility to override a default value:
  > Decl literals can also be used to ensure data [invariants are not violated](https://ziglang.org/download/0.14.0/release-notes.html#Decl-Literals) by overriding single fields.
- [zig/style] He finds it unclear which style to use in his own structs. ^f5
  > It isn't obvious which approach I should use in my own structs and which is being used by other structs, including the standard library.
- [zig/api] Checked, not there: decl literals calling functions (`.init(allocator)`) are not covered. ^f6

## Read

- Whole post.
