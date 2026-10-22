---
title: Learning Zig - Style Guide (Karl Seguin)
url: https://www.openmymind.net/learning_zig/style_guide/
kind: book
commit:
for: [zig-style]
looked: 2026-10-22
depth: docs (whole chapter)
relevance: medium
grade: B/fair
description: Short chapter on compiler-enforced unused-variable and shadowing rules and std naming convention
---
# Learning Zig - Style Guide (Karl Seguin)

Why: naming and compiler-enforced style, as taught to newcomers.

## Assessment

- Evidence: B. Widely read community intro by the http.zig maintainer (1621 stars, 30
  contributors); revised for 0.16. Not core team.
- Reasoning: fair. States rules and gives his own opinion where he disagrees.
- Interests: none known.
- Weigh: naming rules match the std; his dislike of the shadowing rule is opinion.

## Findings

- [zig/style] Types, variables holding types and functions returning types are PascalCase; functions camelCase, variables snake_case. ^f1
  > Variables which reference a type, or functions which return a type, follow the type rule and are PascalCase.
- [zig/style] Builtins follow the same rule: `@TypeOf` is PascalCase because it returns a type. ^f2
  > `@TypeOf` is also a builtin function, but it's PascalCase, why? Because it returns a type and thus the type naming convention is used.
- [zig/style] Unused locals and parameters are compile errors; discard with `_ = x;`. He prefers that over naming the parameter `_`, which hides what it was. ^f3
  > in my opinion, this leaves a reader guessing what the unused parameter is
- [zig/style] Shadowing an outer identifier is a compile error; he dislikes it because it pushes towards short names like `n`. ^f4
  > I am not a fan of this rule as it generally leads developers to use short meaningless names.
- [zig/style] `zig fmt` fixes indentation and braces but not identifier casing, so naming is on the author. ^f5
  > it will adjust indentation and brace positions, but won't change identifier casing.
- [zig/style] Unused imports (`const std = @import("std")`) are not an error. ^f6
  > Notice that `std` is also unused but does not generate an error.

## Read

- Whole chapter.
