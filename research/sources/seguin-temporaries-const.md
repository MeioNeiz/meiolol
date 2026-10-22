---
title: Zig's Temporary Variable are Const (Karl Seguin, 2024)
url: https://www.openmymind.net/Zigs-Temporary-Variables-are-Const/
kind: article
commit:
for: [zig-style, zig-api-design]
looked: 2026-10-22
depth: docs (whole post)
relevance: low
grade: B/fair
description: Why &.{...} gives *const [N]T and method calls on temporaries fail: temporaries are const; take []const T
---
# Zig's Temporary Variable are Const (Karl Seguin, 2024)

Why: a frequent compile error and the const-parameter lesson.

## Assessment

- Evidence: B. Practitioner, Jul 2024; semantics unchanged.
- Reasoning: fair; he guesses at the rule ("I believe").
- Interests: none known.
- Weigh: the advice (take `[]const T` when not mutating) is sound regardless.

## Findings

- [zig/api] Take `[]const T` when a function doesn't mutate, so callers can pass literals like `&.{1, 2, 3}`. ^f1
  > In this case, our function _should_ take a `const` since it doesn't mutate `values`.
- [zig/style] Temporaries are const: `DefaultPrng.init(0).random()` fails; bind the value to a `var` first. ^f2
  > if we want data to be mutable, it needs to be explicitly assigned to a variable.
- [zig/style] Make things const whenever possible. ^f3
  > This is a good argument for, whenever possible, making things `const`.

## Read

- Whole post.
