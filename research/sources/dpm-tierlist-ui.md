---
title: 'DPM.LOL: tier list (patch 16.21), re-read'
url: https://dpm.lol/tierlist?tier=emerald_plus
kind: project
commit: 
for: [lol-site-ui]
looked: 2026-10-24
depth: skimmed (rendered text, viewport screenshots 1280x900, phone 390)
relevance: high
grade: B/fair
description: DPM.LOL tier list re-read for role links, sorting, change colour and phone: one row per champion and role, each with its own lane link
---
# DPM.LOL: tier list (patch 16.21), re-read

Why: role links, sorting and how the change is coloured. Extends [[dpm-tier-list]].
Shots: data/team/2026-10-24-ui/refs/tier-list/dpm-tierlist*.png.

## Assessment

- Evidence: B. Popular newer site; live page.
- Reasoning: weak.
- Interests: vendor.
- Weigh: link targets and sort tested headless.

## Findings

- [ux/controls] A champion in two lanes is two rows, each linking its own lane: Yasuo mid (59.3% of his games) and Yasuo bot (17.7%) link build?lane=middle and build?lane=bottom (page links 24 Oct). ^f1
- [ux/controls] Clicking Games re-sorted by games (tested 24 Oct); the rank column kept the tier rank (25, 44, 1, 2...), so order and rank stay separate facts. ^f2
- [ux/colour] The win-rate change under each rate is green when clearly up (+1.3%), red when clearly down (-1.0%) and grey when near zero (-0.2%) (seen in screenshot dpm-tierlist.png). ^f3
- [ux/density] Rows about 44 px, 15 a screen; champion cell is a 58 px wide splash crop plus name (seen in screenshot dpm-tierlist.png). ^f4
- [ux/density] Phone: keeps rank, champion, lane icon with share, tier, win rate, pick rate; drops games and the change (seen in screenshot dpm-tierlist-phone.png). ^f5

## Read

- Page text and links; desktop and phone shots

## Not read

- Off-meta toggle behaviour
