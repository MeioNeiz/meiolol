---
title: 'Shopify Polaris content guidelines: fundamentals, grammar and mechanics, tooltip'
url: https://github.com/Shopify/polaris/tree/main/polaris.shopify.com/content
kind: docs
commit: 3f7954ae42fabf26d63cee68c23ceebfd7ef0972
for: [ui-guardrails]
looked: 2026-10-22
depth: docs (content fundamentals, headings and links sections, tooltip)
relevance: high
grade: A/fair
description: Shopify Polaris's content rules (archived repo, source of polaris.shopify.com): weigh every word, icon over word, one learn-more link per screen, tooltips concise and sparing; no numeric word limits
---
# Shopify Polaris content guidelines: fundamentals, grammar and mechanics, tooltip

Why: concrete copy limits per element in a mature design system.

## Assessment

- Evidence: A. Shopify's design system since 2017 (6.2k stars), used across the Shopify
  admin by many teams; repo archived, guidance moved to shopify.dev web components.
- Reasoning: fair. Rules with do/don't examples and short reasons ("adds noise").
- Interests: none.
- Weigh: the rules are qualitative; Polaris sets no word or character counts, only a
  reading level and per-screen counts (one learn-more link).

## Findings

- [ux] Every word and full stop is treated as noise to be justified. `content/content/fundamentals.mdx` ^f1
  > But each word and every period adds noise to the experience. So weigh every word.
- [ux] Icons over words where they work, and subcopy is optional even when the component
  has a slot for it. `fundamentals.mdx` ^f2
  > Let visuals and icons do the talking wherever you can
  > not every situation calls for subcopy, even if the component has been designed to include it
- [ux] Test: could the word be an icon, could header plus subcopy plus button be one
  button. `fundamentals.mdx` ^f3
  > Ask yourself, could this word be an icon? Could this header, subcopy, and button just be a button?
- [ux] Too much text makes a tool feel cheap and hard; the target is the least that still
  works ("Jenga"). `fundamentals.mdx` ^f4
  > Too much content makes a tool feel cheap and that it's hard to use.
  > Approach content like Jenga. What's the most you can take away before things fall apart?
- [ux] One checkable number: 7th grade reading level. `fundamentals.mdx` ^f5
  > Aim for a 7th grade reading level
- [ux/layout] Don't front-load info; importance through type size and position; split
  multi-part tasks (progressive disclosure). `fundamentals.mdx` ^f6
  > Don't overwhelm people with too many choices or too much info upfront
  > Use design (font size, location on the screen) to communicate importance
- [ux] Headings: one sentence at most, no punctuation, sentence case, terse noun phrases
  ("Custom reports", not "This is your online store dashboard"). `grammar-and-mechanics.mdx` Headings ^f7
  > Keep headings to a single sentence
  > Avoid using punctuation such as periods, commas, or semicolons
- [ux/layout] Extra info by size: info icon for short stand-alone info, inline link, or
  "learn more" for longer; at most one learn-more per screen; links add clutter. `grammar-and-mechanics.mdx` Links ^f8
  > use the info icon (for short, stand-alone info), an embedded link (within the flow of an existing sentence), or a “learn more” link (for longer, multi-faceted info)
  > If you have to include “learn more” links, avoid having more than one per screen
  > Links add clutter and make things feel less like software, more like an old-fashioned webpage
- [ux] Tooltips: succinct, never critical information, no links or buttons, used
  sparingly; many tooltips mean the design or wording needs fixing. `components/overlays/tooltip.mdx` ^f9
  > Not be used to communicate critical information, including errors in forms or other interaction feedback.
  > Be used sparingly. If you’re building something that requires a lot of tooltips, work on clarifying the design and the language in the experience.
- [ux] Checked, not there: no word or character count for headings, tooltips, buttons or
  body copy anywhere in these three files. ^f10
- [ux] (inferred) Checkable for meio.lol: headings without full stops, at most one
  learn-more per page, tooltip count per page as a smell, a reading-level score. ^f11

## Read

- fundamentals.mdx (all), grammar-and-mechanics.mdx headings and links, tooltip.mdx

## Not read

- grammar-and-mechanics numbers, dates and punctuation sections; naming.mdx; the new
  shopify.dev web component docs
