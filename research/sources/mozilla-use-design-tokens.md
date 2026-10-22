---
title: 'Firefox Source Docs: stylelint-plugin-mozilla use-design-tokens rule'
url: https://firefox-source-docs.mozilla.org/code-quality/lint/linters/stylelint-plugin-mozilla/rules/use-design-tokens.html
kind: docs
commit: 
for: [ui-tooling]
looked: 2026-10-22
depth: docs (rule overview)
relevance: high
grade: A/fair
description: Firefox's own stylelint rule that fails CSS declarations using hardcoded values instead of design token variables, per property, switched on property by property in rollouts
---
# Firefox Source Docs: stylelint-plugin-mozilla use-design-tokens rule

Why: how a large, mature front end enforces design tokens in CSS.

## Assessment

- Evidence: A. Rule in the Firefox tree's lint suite, documented for all Firefox
  front-end contributors.
- Reasoning: fair. States purpose and config; no data on how many violations it found.
- Interests: none.
- Weigh: shows the pattern (per-property token lint, rolled out property by property);
  the rule itself is stylelint, i.e. Node.

## Findings

- [web/qa] Firefox lints CSS so declarations use design token variables, not hardcoded
  values. Intro ^f1
  > This rule checks that CSS declarations use design token variables instead of hardcoded values.
- [web/qa] Each property can be switched off on its own, which is how it is rolled out
  across an existing codebase. Configuration ^f2
  > // Disable specific properties (common in rollouts)
- [web/qa] (inferred) Same shape fits meiolol's planned Zig CSS test: per-property
  checks (colour, font-size, spacing, radius) enabled one at a time as style.css is
  migrated, rather than a big-bang lint. ^f3

## Read

- Overview page

## Not read

- Per-property pages other than color (see mozilla-use-design-tokens-color)
