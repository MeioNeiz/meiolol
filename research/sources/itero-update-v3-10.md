---
title: 'iTero app update 3.10: Simplified Summary scouting view (Aug 2026)'
url: https://www.itero.gg/articles/app-update-v3-10
kind: article
commit:
for: [champselect-advice-methods]
looked: 2026-11-06
depth: docs (full article)
relevance: medium
grade: C/fair
description: iTero 3.10 (10 Aug 2026): pre-game scouting screen now defaults to human-readable tags with basic stats, after users found the numbers and graphs overwhelming; RAM cut, logged-out states
---
# iTero app update 3.10: Simplified Summary scouting view (Aug 2026)

Why: what iTero changed recently in how much number detail the pre-game screens show.

## Assessment

- Evidence: C. Vendor changelog, Aug 2026; "proved more popular" given without numbers.
- Reasoning: fair. Says why (new users overwhelmed) and keeps the old view as a setting.
- Interests: vendor.
- Weigh: a direction signal (fewer numbers by default), not a measured result.

## Findings

- [ux/desktop] [ux/uncertainty] The scouting screen (shown while loading in) gets a Simplified Summary of tags instead of graphs and numbers, now the default. ^f1
  > which uses human readable tags instead of graphs and numbers. Then we made it the default view.
- [needs] [ux/trust] The stat-heavy screen suited analytical players but more found it overwhelming and unusable. ^f2
  > there were also a lot MORE people who thought it was overwhelming and unusable!
- [ux/desktop] (claim) Tags proved more popular at once; the old view stays in settings. ^f3
  > This immediately proved more popular than my stat-heavy approach, so we switched it to be the default view.
- [ux/desktop] Logged-out states now hide features that need a League login instead of filling screens with warnings. ^f4
  > so that you can only navigate to working features until you log-in
- [tools] ARAM next: a non-data-driven augment tier list, explicitly not an AI win rate optimiser. ^f5
  > We’re **NOT** building an AI-powered macro coach to hyper-optimise your ARAM win rate.

## Read

- Whole article.

## Not read

- 3.11 ARAM update.
