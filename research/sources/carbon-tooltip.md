---
title: 'IBM Carbon: Tooltip usage (with definition tooltip and toggletip)'
url: https://carbondesignsystem.com/components/tooltip/usage/
kind: docs
commit: 
for: [ui-guardrails]
looked: 2026-10-22
depth: docs (usage, content, behaviours)
relevance: high
grade: A/fair
description: IBM Carbon's tooltip guidance: built into components, icon tooltips one or two words, definition tooltips (dotted underline) for terms in labels and data tables, toggletips on click when content is interactive
---
# IBM Carbon: Tooltip usage (with definition tooltip and toggletip)

Why: how a data-heavy enterprise system explains terms in tables without clutter.

## Assessment

- Evidence: A. IBM's open design system, used across IBM's data and cloud products.
- Reasoning: fair. Distinguishes tooltip, definition tooltip and toggletip by trigger
  and content.
- Interests: none.
- Weigh: the definition tooltip is the closest match to meio.lol's column headers.

## Findings

- [ux] Tooltips are used only when needed, for quick context without clutter. Overview ^f1
  > should only be used when necessary to offer quick context without cluttering the interface.
- [ux] Icon tooltips: a one or two word description. Content, Text ^f2
  > Tooltips for icon-only components, like icon buttons, should provide a concise one- or two-word description of the button's function.
- [ux/layout] No essential instructions in tooltips, since they don't persist. Content, Text ^f3
  > Should not contain essential task instructions since a tooltip is not persistent.
- [ux/density] Definition tooltips (dotted underline) suit labels and data tables, where
  icons would clutter. Definition tooltip ^f4
  > It works well on UI labels, words in paragraphs, or compact spaces like data tables, where extra icons might clutter the interface.
- [ux/layout] Definition tooltips open on hover or click; click when the reader needs time. Interactions ^f5
  > Users can click if they need more time or if the tooltip might be unintentionally triggered.
- [ux/layout] Tooltip on hover or focus for brief non-interactive text; toggletip on click
  or Enter when it holds links or buttons. Tooltips versus toggletips ^f6
  > A toggletip is used on click or enter when you must expose interactive elements, such as a button, that a user needs to interact with.
- [web/qa] No interactive elements in tooltips: they never get focus. Include interactive elements ^f7
  > Interactive elements in tooltips are inaccessible for some users and are hard to use for all users since tooltips do not receive focus.
- [ux/density] (inferred) For meio.lol's tables: column headers keep a short label with a
  dotted underline opening a definition on hover or tap, instead of prose above the
  table or an info icon per column. ^f8

## Read

- Tooltip usage page

## Not read

- Toggletip component page; Carbon content guidelines; disclosures pattern
