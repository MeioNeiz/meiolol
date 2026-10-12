---
title: Scripty Basics (Zine docs)
url: https://zine-ssg.io/docs/scripty/
kind: docs
for: [zig-html-templates]
looked: 2026-10-12
depth: docs (all)
relevance: medium
grade: B/fair
description: Scripty, the expression-only language SuperHTML and SuperMD embed in attribute strings
---
# Scripty Basics (Zine docs)

Why: what language sits inside SuperHTML attributes.

## Assessment

- Evidence: B. Official docs, short.
- Reasoning: fair. States the design (expressions only, host-defined globals), little
  on costs.
- Interests: author's own project.
- Weigh: plain description of the syntax; trust.

## Findings

- [web/template] Scripty is expressions only: no statements or blocks, every expression
  starts at a `$` global and navigates fields and calls functions. `#scripty-syntax` ^f1
  > For this reason Scripty doesn’t have statements or blocks of any kind and can only be used to build expressions.
  > All variables available in the global scope are prefixed with a `$` which means in turn that all Scripty expressions start with a `$`.
- [web/template] Literals: string, 64-bit int, 64-bit float, bool. `#literals` ^f2
  > Scripty supports also a limited set of literals:
- [web/template] The host language decides globals and their meaning; SuperHTML and
  SuperMD use the same syntax with different semantics. `#global-scope` ^f3
  > it’s entirely up to the host language to define which variables are available in the global scope and their semantics.

## Read

- All

## Not read

- SuperMD docs: content format, out of scope (we generate HTML from data)
