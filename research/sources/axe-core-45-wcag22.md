---
title: 'Deque blog: Axe-core 4.5: First WCAG 2.2 Support and More (2022)'
url: https://www.deque.com/blog/axe-core-4-5-first-wcag-2-2-support-and-more/
kind: article
commit: 
for: [ui-tooling]
looked: 2026-10-22
depth: skimmed
relevance: medium
grade: A/fair
description: axe-core 4.5 release notes: target-size rule (24 px or 24 px clear space, WCAG 2.5.8) off by default; few WCAG 2.2 criteria automatable; link-in-text-block on by default
---
# Deque blog: Axe-core 4.5 (2022)

Why: can axe check tap target size, and is it on by default?

## Assessment

- Evidence: A. Release notes by axe-core's maintainer.
- Reasoning: fair. Explains why most WCAG 2.2 stays manual.
- Interests: vendor.
- Weigh: "off by default" is as of 4.5; check the current axe tag set when wiring it.

## Findings

- [web/qa] target-size: controls at least 24 px each way, or that much space from the
  nearest control (WCAG 2.2 2.5.8). Target size ^f1
  > Axe-core’s new \`target-size\` rule tests if links, buttons, form fields, and other controls have a width and height of at least 24 pixels, or if they don’t, that they have that much space from the closest other control.
- [web/qa] Off by default; needs the WCAG 2.2 ruleset enabled. Target size ^f2
  > Until WCAG 2.2 is a W3C Recommendation that is more widely required, this rule will be off by default.
- [web/qa] Few WCAG 2.2 criteria can be automated without false positives. Target size ^f3
  > Because of how few new success criteria in WCAG 2.2 can be automated without false positives, the \`target-size\` rule is likely the only rule for WCAG 2.2 that will be added to axe-core.
- [web/qa] [ux/colour] link-in-text-block now on by default: links in text need an
  underline or 3:1 contrast to surrounding text. ^f4
  > The \`link-in-text-block\` rule is no longer listed as experimental, and will now be enabled by default.

## Read

- Release post

## Not read

- Other 4.5 changes
