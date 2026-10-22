---
title: 'stylelint-declaration-strict-value (README)'
url: https://raw.githubusercontent.com/AndyOGo/stylelint-declaration-strict-value/master/README.md
kind: project
commit: 
for: [ui-tooling]
looked: 2026-10-22
depth: docs (README to Multiple Properties)
relevance: medium
grade: B/fair
description: Generic stylelint plugin that requires variables or functions (not literals) for chosen properties, with ignore lists per property; the usual open-source token lint
---
# stylelint-declaration-strict-value (README)

Why: the common off-the-shelf token lint, to see what config a token lint needs.

## Assessment

- Evidence: B. Since Dec 2016, 145 stars, pushed Aug 2026; widely referenced but small.
- Reasoning: fair. Clear examples.
- Interests: none.
- Weigh: Node tool; its option set is a checklist for our own Zig lint.

## Findings

- [web/qa] Enforces variables, functions or allowed keywords for listed properties;
  literals warn. Intro, Usage ^f1
  > The following patterns are considered **warnings:**
  > a { color: #FFF; }
- [web/qa] Properties can be regexes (`/color$/`), and z-index and font-size are typical
  targets alongside colour. Multiple Properties ^f2
  > ["/color$/", "z-index", "font-size"]
- [web/qa] Per-property ignore lists (ignoreValues) and toggles for variables and
  functions are the knobs. Scheme ^f3
  > ignoreValues: "string" || "/RegExp/[gimsuy]" ||
- [web/qa] (inferred) Everything it checks is one regex over declarations: a Zig test over
  the embedded CSS can do the same without Node. ^f4

## Read

- README to Multiple Properties

## Not read

- Autofix, expandShorthand details
