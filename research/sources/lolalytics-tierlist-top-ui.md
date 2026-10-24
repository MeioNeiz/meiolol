---
title: 'LoLalytics: tier list, top lane (patch 16.21)'
url: https://lolalytics.com/lol/tierlist/?lane=top
kind: project
commit: 
for: [lol-site-ui]
looked: 2026-10-24
depth: skimmed (rendered text, viewport screenshots 1280x900, phone 390)
relevance: high
grade: B/fair
description: LoLalytics tier list re-read for sorting, filters, role links and phone: every header sorts, minimum inputs in the top strip, lane carried in row links
---
# LoLalytics: tier list, top lane (patch 16.21)

Why: Jacob's reference site; how its champions table sorts, filters and links by role.
Extends [[lolalytics-tierlist-pbi]] (20 Oct). Shots: data/team/2026-10-24-ui/refs/tier-list/lolalytics-tierlist*.png.

## Assessment

- Evidence: B. Large, long-running stats site; live page.
- Reasoning: weak (no explanation of choices).
- Interests: vendor, ad-funded.
- Weigh: behaviour tested headless (header click, link targets); visuals from screenshots.

## Findings

- [ux/controls] Row links carry the lane: an off-role row links the build page with ?lane=top, the champion's main lane links without it (main lane is the default): Zed links /lol/zed/build/?lane=top, Darius /lol/darius/build/ (page links 24 Oct). ^f1
- [ux/controls] Clicking the Games header re-sorted the table by games, descending (tested headless 24 Oct); every header is a sort key. ^f2
- [ux/controls] Minimums are three visible number inputs in the sticky filter strip (Min Lane % 2, Min Games 100, Min Pick % 0) beside lane icons, patch, queue and region, not a dropdown (seen in screenshot lolalytics-tierlist.png). ^f3
- [ux/density] Two header groups in one row: Emerald+ performance (rank, icon, name, tier, lane with lane share, win with change beneath, pick, ban, PBI, games) and the best players on the champion (rank, win, games, delta, elo badge). ^f4
  > Best Worldwide on Champion
- [ux/layout] Failure: an ad, a video and a 140-word paragraph put row 1 at about y 630 of a 900 px window (seen in screenshot lolalytics-tierlist.png). ^f5
- [ux/density] Phone (390 px): keeps icon, name, tier, lane, win, pick, ban; drops PBI, games and the best-players group; the paragraph still comes first (seen in screenshot lolalytics-tierlist-phone.png). ^f6

## Read

- Page text and links; desktop and phone shots

## Not read

- Grid view, other lanes
