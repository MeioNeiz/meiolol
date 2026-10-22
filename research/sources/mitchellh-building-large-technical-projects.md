---
title: My Approach to Building Large Technical Projects (Mitchell Hashimoto)
url: https://mitchellh.com/writing/building-large-technical-projects
kind: article
for: [zig-testing]
looked: 2026-10-22
depth: docs (full)
relevance: low
grade: C/fair
description: June 2023 essay, not Zig-specific: pick sub-projects that show results soon, unit tests as early visible progress, good-enough components, demos weekly, dogfood
---
# My Approach to Building Large Technical Projects (Mitchell Hashimoto)

Why: how did Ghostty's author sequence the work, and where do tests fit?

## Assessment

- Evidence: C. A personal method; he says it may not suit others.
- Reasoning: fair. Explains the motivation logic; no evidence beyond his projects.
- Interests: none.
- Weigh: process advice, not Zig practice. One useful line for testing: start with a part
  that is easy to unit test.

## Findings

- [zig/test] Unit tests are how backend work shows results before any UI exists. ^f1
  > The best tool to get past this phase is automated testing (usually unit testing at this stage).
- [zig/test] He started Ghostty with the VT parser because it was easy to test: input string in, parsed actions out. ^f2
  > it felt like something that I could very easily test: give it some example input as a string, expect some parsed action or event as output.
- [zig] Early components are good enough, not finished: in-memory data, built-in structures, inputs up front. ^f3
  > do not let perfection be an enemy of progress.
- [zig] He throws away demo tooling freely (an ASCII grid CLI for the parser). ^f4
  > the CLI I was writing was relatively useless long term (I ended up throwing it away rather quickly).

## Read

- Full post

## Not read

- n/a
