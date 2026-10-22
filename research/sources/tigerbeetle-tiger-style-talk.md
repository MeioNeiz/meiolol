---
title: TigerStyle! (Or How To Design Safer Systems in Less Time), Joran Dirk Greef, Systems Distributed 2023
url: https://www.youtube.com/watch?v=w3WYdYyjek4
kind: talk
commit:
for: [zig-errors-safety, zig-good-practice, zig-memory]
looked: 2026-10-22
depth: docs (whole transcript, auto captions)
relevance: medium
grade: A/fair
description: TigerBeetle CEO's talk on Tiger Style: design before code, assertions as tripwires, limits on everything, assertions on in production, simulation as a time machine
---
# TigerStyle! (Or How To Design Safer Systems in Less Time), Joran Dirk Greef, 2023

Why: the spoken rationale behind TIGER_STYLE.md, by its author.

## Assessment

- Evidence: A for what Tiger Style means (its author). 62 min, 86.6k views, 2.4k
  likes; April 2023 (Zig 0.10/0.11 era). Auto captions: names and numbers misheard
  ("3 000 discussions" is assertions).
- Reasoning: fair. Persuasive keynote style; strong on why assertions and limits,
  light on costs.
- Interests: TigerBeetle founder at the company's own conference.
- Weigh: trust the reasoning on assertions vs errors and limits; the timing claims
  ("thousand X") are rhetoric.

## Findings

- [zig/style] Most time goes to testing and production, so spend time on design;
  "go slow to go fast". @9:03 ^f1
  > an hour or day of design is worth weeks or months in production
- [zig/build] Avoid dependencies chosen for popularity; TigerBeetle was "painted" from
  scratch because dependencies would slow testing and add risk. @16:34 ^f2
  > we saw that the dependencies were going to slow down testing they were going to introduce safety and performance risk
- [zig/safety] Assert every argument and return value, and how they relate to each
  other and program state: a function's job is correctness. @27:06 ^f3
  > every function should be checking as stuff comes in as stuff goes out
- [zig/safety] Assert the negative space, as a hacker would: what you do not expect.
  @30:06 ^f4
  > start to think like a hacker like what don't you expect
- [zig/safety] Avoid `while (true)` except for an event loop; bound loops and assert
  both upper and lower bounds. @31:36 ^f5
  > to use a finite for loop with a fixed upper bound then you can detect runaway Loops that can deadlock production
  > you have to assert the lower bound
- [zig/memory] Limits make overload handling and backpressure possible; static
  allocation is one case of everything having a limit, and uses less memory. @34:37 ^f6
  > if you don't know the limits you can't handle overload
  > you actually use less memory when you do static allocation
- [zig/safety] A cache-versus-disk assertion caught a rare bug during benchmarking
  that tests had missed; it took 8 hours to debug instead of months. @36:07 ^f7
  > the assertion coded we didn't have test coverage but an assertion called it while benchmarking
- [zig/errors] [zig/safety] Operating errors (e.g. out of memory: refuse new
  connections) are handled; programming errors can't be predicted, so the only safe
  response is to shut down. @39:08 ^f8
  > if your server is low on memory the thing to do is is to not accept more connections
  > if you can predict a bug to handle it correctly why not fix it in the first place
- [zig/safety] Keep assertions on in production; in a fault-tolerant cluster crashing
  a faulty process raises availability. @40:38 ^f9
  > don't turn that off in production
- [zig/safety] Zig's checked arithmetic in safe builds should be standard; opt out per
  block only for covered data-plane code. Comptime assertions check design before the
  program runs, one main reason they chose Zig. @43:38 ^f10
  > in safe bolts checked arithmetic on by default that that should be the standard
  > you can check a program's design Integrity before it even executes
- [zig/style] Assertions document both positive and negative space for the next
  reader, beyond comments. @45:08 ^f11
  > you're showing programmers the positive space your logic and you're showing them the negative space what shouldn't happen

## Read

- Whole transcript.
