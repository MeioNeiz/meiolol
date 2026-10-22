---
title: 'Firefox Source Docs: use-design-tokens, color property'
url: https://firefox-source-docs.mozilla.org/code-quality/lint/linters/stylelint-plugin-mozilla/rules/use-design-tokens/color.html
kind: docs
commit: 
for: [ui-tooling]
looked: 2026-10-22
depth: docs (whole page)
relevance: medium
grade: A/fair
origin: mozilla-use-design-tokens
description: What Firefox's token lint rejects and allows for color: hex, rgba and oklch literals fail, tokens with fallbacks and local aliases of tokens pass, inherit and similar keywords pass
---
# Firefox Source Docs: use-design-tokens, color property

Why: the exact allow/deny rules of a mature token lint, to copy into a Zig test.

## Assessment

- Evidence: A. Same rule as mozilla-use-design-tokens.
- Reasoning: fair. Examples only.
- Interests: none.
- Weigh: a ready-made rule set.

## Findings

- [web/qa] Literal colours fail in any syntax, including a custom property set to a raw
  colour and used as `var(--my-token, raw)`. Incorrect examples ^f1
  > color: oklch(69% 0.19 15);
- [web/qa] Allowed: tokens, tokens with a fallback, and local custom properties that alias
  a token. Correct examples ^f2
  > /* Local CSS variables that reference valid text-color tokens are allowed */
- [web/qa] Keywords such as inherit and initial are allowed. ^f3
  > The rule also allows these non-token values:

## Read

- Whole page

## Not read

- Other properties (font-size, space, border-radius pages)
