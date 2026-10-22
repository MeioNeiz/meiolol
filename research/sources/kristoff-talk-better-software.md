---
title: How To Write Better Software With Zig (Loris Cro, Zigtoberfest 2025)
url: https://www.youtube.com/watch?v=AEybWzeAkho
kind: talk
commit:
for: [zig-good-practice, zig-errors-safety, zig-api-design, zig-build]
looked: 2026-10-22
depth: docs (full transcript)
relevance: medium
grade: B/fair
description: Zig team talk, a top-ten list: own core dependencies, ship a CLI with libraries, no global state, asserts plus fuzzing over many unit tests, zig build should just work
---
# How To Write Better Software With Zig (Loris Cro, Zigtoberfest 2025)

Why: project-level practice from the Zig team.

## Assessment

- Evidence: B. Loris Cro (ZSF VP Community), Oct 2025 conference talk; 9.7k views.
  Mostly project and community advice, some code practice. Auto captions.
- Reasoning: fair; reasons given, few costs.
- Interests: promotes Zig Days, his projects (Zine, SuperHTML).
- Weigh: the code-relevant items (no globals, asserts, check `zig build` works) are
  consistent with his blog and TigerBeetle.

## Findings

- [zig/api] Keep library state in struct instances, never globals, so users can have two; that is also what makes code thread- and async-friendly. ^f1
  > you don't use global variables to stare a state right you to store state you put state inside of a strct and you pass around instances of the extract.
  @9:36
- [zig/api] With Zig's planned Io design, code correct under multithreading should also be fine under async. ^f2
  > all you have to do is the same exact work that you need to do to have your software work correctly in a multi-threaded environment.
  @8:48
- [zig/test] Unit tests are code with momentum and couple to internals; asserts are one line and, with fuzzing, find more. ^f3
  > If you're not like super good at that, you risk also unit testing internals a little bit too much.
  @10:30
  > so you assert your invariance, preconditions, post conditions in an assert.
  @11:20
- [zig/build] Gold standard: on any machine `zig build` just works; minimise and document system dependencies. ^f4
  > Like in Zigg the gold standard is whatever machine zig build boom it works right assuming you have the correct version of zig.
  @14:44
- [zig/build] `zig init`'s root.zig plus main.zig hint: libraries ship a CLI, programs expose reusable logic as a module. ^f5
  > One is root.zig which is going to be your entry point for your library or your module and then you also get I believe main.zig which is the entry point for an executable.
  @8:01
- [zig] Dependencies are technical and design debt: fine to start, but own whatever is core to the product. ^f6
  > So the idea is start with dependencies but eventually get rid of them especially when it comes to critical stuff to the core stuff that your application should be doing.
  @4:29

## Read

- Full transcript.
