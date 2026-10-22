---
title: 'GitLab docs: Vale documentation tests'
url: https://docs.gitlab.com/development/documentation/testing/vale/
kind: docs
commit: 
for: [ui-guardrails]
looked: 2026-10-22
depth: docs (result types, when to add a rule, hooks)
relevance: high
grade: A/strong
description: How GitLab runs the Vale prose linter on its docs: three alert levels, only errors fail CI; rules start as warnings and are promoted once existing hits are fixed; subjective rules kept to suggestion level
---
# GitLab docs: Vale documentation tests

Why: which copy rules a large team checks automatically, and how it keeps a prose lint
from becoming noise.

## Assessment

- Evidence: A. GitLab's own docs process, thousands of pages and many contributors,
  lint in CI and pre-push hooks for years.
- Reasoning: strong. States the trade-off (effort and noise), the rollout path and when
  a rule is too subjective to enforce.
- Interests: none.
- Weigh: docs prose, not UI strings; the levelling policy carries over directly.

## Findings

- [web/qa] Three levels; only errors fail CI; warnings show in the MR diff only;
  suggestions only in local editors. Result types ^f1
  > This configuration is also used in build pipelines, where error-level rules are enforced.
- [web/qa] Errors are kept for branding and broken rendering; style rules are warnings;
  refactoring-sized preferences are suggestions. Result types ^f2
  > **Warning** - For general style guide rules, tenets, and best practices.
- [web/qa] Rollout: an error rule needs zero existing hits; otherwise add it as a warning,
  fix hits in follow-ups, then promote. When to add a new Vale rule ^f3
  > If there are too many issues to fix in a single merge request, add the rule at a `warning` level. Then, fix the existing issues in follow-up merge requests. When the issues are fixed, promote the rule to an `error`.
- [web/qa] Too-subjective rules cannot be enforced and only add noise: weigh how often an
  author would rightly ignore it. When to add a new Vale rule ^f4
  > If the rule is too subjective, it cannot be adequately enforced and creates unnecessary additional warnings.
- [web/qa] The pre-push hook shows only errors, so a clean main branch means any error
  was introduced by the push. Show Vale warnings ^f5
  > The default branches have no Vale errors, so any errors listed here are introduced by the commit to the branch.
- [web/qa] (inferred) For meio.lol: a hard limit (characters per label, words per
  caption) can be an error only once the site has zero hits; word budgets per page start
  as warnings in the build log. ^f6

## Read

- Result types, when to add a rule, hooks, false positives

## Not read

- Editor setup sections
