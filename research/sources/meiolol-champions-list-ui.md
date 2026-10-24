---
title: 'meio.lol: champions list (24 Oct)'
url: https://meio.lol/champions.html
kind: project
commit: 
for: [lol-site-ui]
looked: 2026-10-24
depth: skimmed (rendered text, viewport screenshots 1280x900)
relevance: high
grade: B/fair
description: Our champions table as of 24 Oct: role tabs, sort explained in a sentence, every row links the champion page without its role
---
# meio.lol: champions list (24 Oct)

Why: baseline for the rebuild; the role-link bug Jacob hit.
Shot: data/team/2026-10-24-ui/refs/tier-list/meiolol-champions.png.

## Assessment

- Evidence: B. Our own live page.
- Reasoning: n/a.
- Interests: ours.
- Weigh: page source checked with curl.

## Findings

- [ux/controls] Failure: rows link the champion page with no role; Vel'Koz shows as mid (row 3) and support (row 20) and every Vel'Koz link is the same URL, which opens on support (curl 24 Oct). ^f1
- [ux/layout] A sentence explains the sort above the table. ^f2
  > Sorted by win rate pulled toward the role's average, the more the fewer the games, so a few lucky games can't top it
- [ux/density] Columns: #, champion, role, win rate (interval shape, rate, change beneath), pick, ban, influence, games; 29 px rows, 20 above the fold (seen in screenshot meiolol-champions.png). ^f3

## Read

- Page text and links

## Not read

- Phone layout
