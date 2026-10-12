---
title: 'Zine: A Static Site Generator Written in Zig (Loris Cro, 2024-09-18)'
url: https://kristoff.it/blog/zine-ssg-zig/
kind: article
origin: zine-superhtml-docs
for: [zig-html-templates]
looked: 2026-10-12
depth: listed
relevance: medium
grade: B/fair
description: Author's Zine launch post; SuperHTML section argues valid-HTML templates make errors easy to catch
---
# Zine: A Static Site Generator Written in Zig (Loris Cro, 2024-09-18)

Why: the author's own words on why templates should be valid HTML.

## Assessment

- Evidence: B. First-hand, author of both tools.
- Reasoning: fair. Short; same argument as the docs.
- Interests: launch post.
- Weigh: repeats the docs' rationale; counts as the same origin.

## Findings

- [web/template] The templating language was the first thing he was sure he could
  improve over Hugo; templates are valid HTML with logic in scripted attributes.
  `#superhtml` ^f1
  > the first thing that I was fully confident I could improve upon was the templating language.
  > SuperHTML templates are valid HTML and the templating logic is expressed through scripted attributes.
- [web/template] Treating HTML as structured data makes syntax errors easy to catch and
  enables autoformatting. `#superhtml` ^f2
  > The main upside of treating HTML as structured data (as opposed to what `{{ curly braced }}` templating languages do) is that you can very easily catch syntax errors
- [web/template] Goal stated: catch as many mistakes as possible as early as possible;
  checks admitted incomplete in 2024. `#superhtml` ^f3
  > the goal is to catch as many mistakes as possible, as early as possible.

## Read

- SuperHTML section; skimmed SuperMD and assets sections

## Not read

- SuperMD directives, asset system: content side, out of scope
