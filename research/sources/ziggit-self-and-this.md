---
title: Zig, Self, and This (Ziggit thread, 2024)
url: https://ziggit.dev/t/zig-self-and-this/5030
kind: thread
commit:
for: [zig-style]
looked: 2026-10-22
depth: docs (whole thread)
relevance: medium
grade: C/fair
description: Brainstorm on self: Self vs widget: Widget receiver naming; cites a Loris Cro zig.news post against Self in simple structs
---
# Zig, Self, and This (Ziggit thread, 2024)

Why: receiver and type naming convention.

## Assessment

- Evidence: C. Ten posts, Jul 2024, community regulars (Sze, mnemnion, dude_the_builder);
  no core-team post. Cites Loris Cro's (now 404) zig.news post.
- Reasoning: fair; reasons on both sides.
- Interests: none.
- Weigh: style opinion; the trend among regulars is naming the type and receiver.

## Findings

- [zig/style] Some regulars never write `self: Self`; they name the receiver after the type, as a Loris Cro post argued. ^f1
  > I agree with Mr. Cro's article, always have: I don't use a pronoun when I'm defining a noun, unless the language forces me to.  So member functions are never `(self: Self)`, always `(widget: Widget)`.
- [zig/style] The rename argument for `Self` in file-structs is weak: editors rename easily, and `lexer: Lexer` reads clearer. ^f2
  > But I realize that doing the rename is a trivial task in any editor, so now I feel that having the added clarity of `lexer: Lexer` is worth the
- [zig/style] Middle ground: `self: Widget`, using `Self` only where required (anonymous generic structs). ^f3
  > I don't do `self: Self` unless its required (Anonymous Structs and Files as Structs).
- [zig/style] Zig has no `self` keyword: the receiver is just the first parameter. ^f4
  > the lowercase version refers to something that gives you the instance (not the type) and is just the parameter name in Zig

## Read

- All ten posts (Discourse raw).
