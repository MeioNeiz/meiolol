---
title: 'Tailwind CSS docs: Detecting classes in source files'
url: https://tailwindcss.com/docs/detecting-classes-in-source-files
kind: docs
commit:
for: [css-per-page]
looked: 2026-10-29
depth: docs (whole page)
relevance: high
grade: A/fair
description: How Tailwind v4 finds used classes: plain-text token scan of source files, complete class names only, explicit sources and inline safelists
---
# Tailwind CSS docs: Detecting classes in source files

Why: Tailwind's "only what is used" is a text scan, like our planned wasm class scan; what
does it require of authors and how does it fail?

## Assessment

- Evidence: A. Official v4 docs; the scan runs on a very large user base.
- Reasoning: fair. Explains the rule and the failure mode with examples.
- Interests: vendor docs.
- Weigh: trust.

## Findings

- [web] Tailwind scans the project for class names and generates CSS for those it finds. ^f1
  > Tailwind works by scanning your project for utility classes, then generating all of the necessary CSS based on the classes you've actually used.
- [web] The scan reads every source file as plain text, not code, and drops tokens that are not known utilities. ^f2
  > Tailwind treats all of your source files as plain text, and doesn't attempt to actually parse your files as code in any way.
- [web] Failure mode: class names built at runtime (concatenation, interpolation) are invisible, so authors must write complete names. ^f3
  > Since Tailwind scans your source files as plain text, it has no way of understanding string concatenation or interpolation in the programming language you're using.
  > As long as you always use complete class names in your code, Tailwind will generate all of your CSS perfectly every time.
- [web] Escape hatch: `@source inline()` forces classes that appear in no file (a safelist). ^f4
  > If you need to make sure Tailwind generates certain class names that don’t exist in your content files, use `@source inline()` to force them to be generated:
- [web] Several sheets are possible by giving each its own sources, e.g. an admin sheet; this is per-area, not per-page. ^f5
  > This can be useful in projects that have multiple Tailwind stylesheets where you want to make sure each one only includes the classes each stylesheet needs.
- [web] (inferred) Same contract a per-page scheme of ours would have: a class name only reachable through runtime string building (island wasm assembling a name) would be missed by a scan, so names must stay literal. ^f6
