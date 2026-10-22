---
title: 'Atlassian ESLint plugin: ensure-design-token-usage'
url: https://atlassian.design/components/eslint-plugin-design-system/ensure-design-token-usage/usage
kind: docs
commit: 
for: [ui-guardrails]
looked: 2026-10-22
depth: docs (rule page; plugin rule list from the nav)
relevance: high
grade: A/fair
description: Atlassian's ESLint rule that fails hardcoded colours (and optionally space and shape) in favour of design tokens, with autofix; the plugin's ~55 rules also lint margins, raw buttons and anchors, missing labels and headings
---
# Atlassian ESLint plugin: ensure-design-token-usage

Why: which visual rules a large design system enforces in code, and with what scope.

## Assessment

- Evidence: A. Atlassian Design System lint used across Jira, Confluence and the rest.
- Reasoning: fair. Gives the reason (theming incidents) and the migration options.
- Interests: none.
- Weigh: rule names show what is lintable; thresholds live in the token set.

## Findings

- [web/qa] [ux/colour] Colour tokens are mandatory, space and shape tokens strongly
  recommended; untokened colour breaks theme switching. ensure-design-token-usage ^f1
  > All experiences must use color tokens otherwise when switching between themes, unexpected incidents can occur where not all of the UI is themed.
- [web/qa] Any hardcoded value or legacy theme colour is a violation. ^f2
  > Using anything other than design tokens such as hardcoded values or legacy theme colors will be considered violations.
- [web/qa] Scope grows by domain: colour by default, spacing and shape opted in, which is
  how the lint is rolled out. Options, domains ^f3
  > An array specifiying which token domains to lint against (`color`, `spacing`, `shape`). Defaults to \[`'color'`\] if not provided.
- [web/qa] The same plugin lints much more than tokens: Use tokens space, Use tokens
  typography, No margin, No html button, Icon label, Use heading, Prefer primitives
  (rule list in the page navigation). ESLint plugin nav ^f4
  > Use tokens typography
- [web/qa] (inferred) Pattern for meio.lol: colour first (it is what carries meaning),
  then spacing and type sizes; raw buttons outside the component set are lintable too.
  ^f5

## Read

- Rule page and the plugin's rule list

## Not read

- Individual pages for use-tokens-typography, no-margin, prefer-primitives
