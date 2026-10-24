---
title: OP.GG Multi-search (Oct 2026)
url: https://op.gg/lol/multisearch/euw
kind: project
commit: 
for: [lol-site-ui]
looked: 2026-10-24
depth: docs (five Challenger EUW players pasted; screenshots; raw is the empty page, no names)
relevance: medium
grade: A/fair
description: OP.GG's multi-search: paste up to five Riot IDs, get five columns of rank, record, role split, last ten games and a ten-row champion pool with KDA, games and win rate
---
# OP.GG Multi-search (Oct 2026)

Why: lol-site-ui, kind 7: how a site shows several players' champion pools side by
side (the champ select lookup players use). Screenshots in
data/team/2026-10-24-ui/refs/pool-draft/opgg-multisearch.png and
opgg-multisearch-pools.png (gitignored, names visible there only).

## Assessment

- Evidence: A. The largest LoL stats site; multi-search is in its main nav.
- Reasoning: weak. No explanation; numbers only.
- Interests: ad funded: a video ad beside the paste box, a 130 px ad slot above the
  columns, a floating video ad.
- Weigh: the per-player pool column is a compact pool display; the use (looking up
  teammates in champ select) is what our rules forbid.

## Findings

- [ux/controls] Input is a textarea for pasted Riot IDs, comma separated, a region
  dropdown and one "Search multiple summoners" button (screenshot 24 Oct). ^f1
- [ux/density] Five 215 px columns, one per player: season badges, rank and LP, a
  win/loss bar with win rate, top two roles with share and win rate, a streak pill, ten
  recent K/D/A chips in two columns (red or blue), then ten champion rows of icon, KDA,
  games and win rate (screenshot 24 Oct). ^f2
- [ux/colour] Win rates are red when high (55%+), grey otherwise; KDA green above about
  3, with no key (screenshot). ^f3
- [ux/layout] The first screen at 1280x900 is the paste box, a video ad and an ad slot;
  player columns start about 560 px down and the pool rows below the fold. ^f4
- [policy] (inferred) Multi-search is the champ select teammate lookup: other players'
  names and stats, which meio.lol may not show in champ select; fine as a post-game or
  profile pattern only. ^f5

## Read

- One five-player result.

## Not read

- "Recent Champions" toggle.
