---
title: 'Shopify: Stylelint Polaris (design system coverage lint)'
url: https://raw.githubusercontent.com/Shopify/polaris/main/polaris.shopify.com/content/tools/stylelint-polaris.mdx
kind: docs
commit: 3f7954ae42fabf26d63cee68c23ceebfd7ef0972
for: [ui-guardrails]
looked: 2026-10-22
depth: docs (tool page, rule postamble, one rule; archived repo)
relevance: high
grade: A/fair
description: Shopify's stylelint config, 40+ rules in 10 categories (colour, space, typography, layout, motion...), that measures Polaris coverage in the Shopify admin; generated disables unblock adoption, hand disables need a reason
---
# Shopify: Stylelint Polaris (design system coverage lint)

Why: how a big design system enforces its tokens across many teams, and how it rolls
the lint out over existing code.

## Assessment

- Evidence: A. Used across the Shopify admin; 15 major versions tracked against
  Polaris releases. The repo is now archived (Polaris moved to web components), so
  this is the record of a mature practice, not a live tool.
- Reasoning: fair. Explains the rollout path; little on which rules caught most.
- Interests: none.
- Weigh: mechanism transfers to a Zig CSS test; per-rule detail is Shopify-specific.

## Findings

- [web/qa] 40+ rules grouped by category measure design-system coverage, not just
  errors: border, colour, conventions, layout, media queries, motion, shadow, space,
  typography, z-index. `stylelint-polaris.mdx` Rules ^f1
  > These rules help us measure the Polaris design system's coverage in the Shopify admin code base using the following categories:
- [web/qa] [ux/colour] Example rule: no hex colours, use the role token.
  `rules/color-color-no-hex.mdx` ^f2
  > description: Disallows hex colors.
- [web/qa] Rollout on existing code: a migration inserts generated disable comments
  ("DO NOT COPY") so the lint can be switched on before every failure is fixed.
  Ignoring existing failures ^f3
  > It is important to fix as many failures upfront as possible, but that shouldn't block the linter from being added.
- [web/qa] Intentional divergence is allowed only with a disable comment stating why;
  the alternative offered is contributing the pattern back. `_postamble.mdx` ^f4
  > Make sure to provide context as to why you are writing custom styles with a disable description.
- [web/qa] (inferred) Same shape as GitLab's Vale levels: switch the rule on at once,
  grandfather old hits visibly, require a reason for new exceptions. For meio.lol a Zig
  test can count raw colour or px literals per file against a shrinking allowance. ^f5

## Read

- Tool page, postamble, color-no-hex rule

## Not read

- The other 40 rule pages; the coverage plugin source in stylelint-polaris/plugins
