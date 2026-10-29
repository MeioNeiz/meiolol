---
title: 'Tailwind CSS v3 docs: Optimizing for Production'
url: https://v3.tailwindcss.com/docs/optimizing-for-production
kind: docs
commit:
for: [css-per-page]
looked: 2026-10-29
depth: docs (whole page)
relevance: high
grade: A/fair
description: Tailwind's case for one small cached sheet instead of per-page CSS: only used utilities are generated, usually under 10 kB compressed
---
# Tailwind CSS v3 docs: Optimizing for Production

Why: Tailwind's stated reason for not splitting CSS per page.

## Assessment

- Evidence: A. Tailwind is the default CSS of Phoenix, Rails 7+ options and many stacks.
- Reasoning: fair. One argument (small file, so no splitting) with one example number.
- Interests: vendor docs; the Netflix number is a single showcase.
- Weigh: the under-10 kB claim fits utility-only sites; component-heavy CSS differs.

## Findings

- [web] Tailwind generates only the CSS the project actually uses. ^f1
  > aims to produce the smallest CSS file possible by only generating the CSS you are _actually using_ in your project.
- [web] Number: usually under 10 kB after minify and compression, even for large projects; Netflix Top 10 ships 6.5 kB of CSS. ^f2
  > this usually leads to CSS files that are less than 10kB, even for large projects.
  > the entire website delivers only 6.5kB of CSS over the network.
- [web] Their conclusion: at that size, skip per-page CSS splitting and ship one small file cached until the next deploy. ^f3
  > With CSS files this small, you don’t have to worry about complex solutions like code-splitting your CSS for each page, and can instead just ship a single small CSS file that’s downloaded once and cached until you redeploy your site.
