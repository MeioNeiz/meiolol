---
title: 'Phoenix guide: Asset management'
url: https://hexdocs.pm/phoenix/asset_management.html
kind: docs
commit:
for: [css-per-page]
looked: 2026-10-29
depth: skimmed
relevance: low
grade: A/fair
description: Phoenix 1.7+ default assets: esbuild for JS, Tailwind builds all CSS into one app.css, no Node needed
---
# Phoenix guide: Asset management

Why: Phoenix's default CSS pipeline.

## Assessment

- Evidence: A. Official guide.
- Reasoning: fair (setup, no rationale).
- Interests: none known.
- Weigh: trust.

## Findings

- [web/template] New Phoenix apps build CSS with Tailwind (via a wrapper, no Node). ^f1
  > From Phoenix v1.7, new applications use [esbuild](https://esbuild.github.io/) to prepare assets via the [Elixir esbuild wrapper](https://github.com/phoenixframework/esbuild), and [tailwindcss](https://tailwindcss.com/) via the [Elixir tailwindcss wrapper](https://github.com/phoenixframework/tailwind) for CSS.
- [web/template] Tailwind handles all CSS building by default. ^f2
  > `esbuild` can also handle your CSS files, but by default `tailwind` handles all CSS building.
- [web/template] Icons are CSS classes so only used icons are sent, via Tailwind's scan. ^f3
  > This is done by embedding icons as CSS classes, which guarantees only the icons actually used by your application are sent to the client, thanks to Tailwind.
- [web/template] Checked, not there: no per-page CSS option in the guide. ^f4
