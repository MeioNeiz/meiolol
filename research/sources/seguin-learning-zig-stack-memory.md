---
title: Learning Zig - Stack Memory (Karl Seguin)
url: https://www.openmymind.net/learning_zig/stack_memory/
kind: book
commit:
for: [zig-memory]
looked: 2026-10-22
depth: docs (whole chapter)
relevance: medium
grade: B/fair
description: Chapter on stack frames and dangling pointers from returning slices into local buffers
---
# Learning Zig - Stack Memory (Karl Seguin)

Why: the stack-lifetime pitfall newcomers hit first.

## Assessment

- Evidence: B. Widely read community intro by the http.zig maintainer; revised for 0.16.
- Reasoning: fair. Explains the mechanism (frame popped) and one fix, admits nothing
  enforces the hidden case.
- Interests: none known.
- Weigh: trust the mechanism; the 0.16 note that the compiler now rejects the simplest
  case (`return &local`) is his report, matches the heap chapter.

## Findings

- [zig/memory] Returning a slice from `bufPrint` into a function-local buffer returns a dangling pointer: the buffer dies with the frame. ^f1
  > that slice points to `buf` which is local to the function. This is called a dangling pointer, a pointer that references invalid memory.
- [zig/safety] Reading through it is undefined: garbage, a segfault, or apparently correct output. ^f2
  > In some cases, it might still work; it isn't like that physical memory is gone and it's possible nothing has changed its value.
- [zig/safety] By 0.16 the compiler rejects his original example, so he had to change it; the slice-through-bufPrint case still compiles. ^f3
  > The snippet that I originally used no longer compiles under Zig 0.16; hence the example was updated (and isn't as good).
- [zig/api] Simplest fix: the caller supplies the output buffer, so the caller owns its lifetime. ^f4
  > the simplest in this case is to have the caller supply the buffer (`[]u8`) to write into. Then it becomes the caller's responsibility to ensure the buffer outlives the formatted value.
- [zig/memory] Hidden version: a parser that keeps a reference to its input outlives the input; nothing in the types enforces the contract, only docs or reading the code. ^f5
  > If `Parser` holds a reference to `input`, that'll be a dangling pointer just waiting to crash our app.
  > But there's nothing here to enforce this contract.
- [zig/memory] If a type needs its input to live as long as it does, it should copy it and own the copy. ^f6
  > Ideally, if `Parser` needs `input` to live as long as it does, it will make a copy of it and that copy will be tied to its own lifetime

## Read

- Whole chapter.
