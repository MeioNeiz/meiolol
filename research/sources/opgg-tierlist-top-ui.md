---
title: 'OP.GG: tier list, top (patch 16.21), re-read'
url: https://op.gg/lol/champions?position=top&region=euw
kind: project
commit: 
for: [lol-site-ui]
looked: 2026-10-24
depth: skimmed (rendered text, viewport screenshots 1280x900, phone 390)
relevance: high
grade: B/fair
description: OP.GG tier list re-read for role links and matchup shortcuts: rows link the role build, the three weak-against icons link straight to that matchup
---
# OP.GG: tier list, top (patch 16.21), re-read

Why: role links and links from the list into matchups. Extends [[opgg-tier-list]].
Shots: data/team/2026-10-24-ui/refs/tier-list/opgg-tierlist*.png.

## Assessment

- Evidence: A. Largest LoL stats site; live page.
- Reasoning: weak.
- Interests: vendor, ad-funded.
- Weigh: headless consent click emptied the table; shots taken with the consent layer removed.

## Findings

- [ux/controls] Champion links carry the role in the path: Darius links /lol/champions/darius/build/top (page links 24 Oct). ^f1
- [ux/controls] Each row's three weak-against icons link straight to that matchup on the counters page (counters/adc?target_champion=sivir for Karthus bot, seen in page links 24 Oct): one click from the list to a matchup. ^f2
- [ux/density] Rank change since last patch sits beside the rank as a coloured arrow and number (Darius up 12, Warwick up 18), so movement costs no column (seen in screenshot opgg-tierlist.png). ^f3
- [ux/layout] Three AI question pills sit above the table, among them "What is the champion with the highest win rate?" (seen in screenshot opgg-tierlist.png). ^f4
- [ux/density] Phone: name dropped, icon only; tier, role, win, pick and counter icons kept (seen in screenshot opgg-tierlist-phone.png). ^f5

## Read

- Page text and links; desktop and phone shots

## Not read

- Sort behaviour (header click blocked by the consent layer)
