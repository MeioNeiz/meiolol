---
title: 'meiolol docs/learned.md: thin data, rare picks, patch day, stored rank (our held-out tests)'
url: 
kind: docs
commit: 18dee313
for: [champselect-advice-methods]
looked: 2026-11-07
depth: docs (docs/learned.md: rare picks, thin pairings, build options, stored rank, patch day)
relevance: high
grade: A/strong
description: Our own held-out results on thin data, rare picks, build option win rates, the stored rank leak and patch day, quoted so claims about rivals' advice can cite them
---
# meiolol docs/learned.md: thin data, rare picks, patch day, stored rank

Why: champselect-advice-methods compares rivals' advice with what our data measured.
Companion of [[meiolol-learned]] (draft lines).

## Assessment

- Evidence: A. Pre-declared held-out tests on ranked games, Platinum IV and up, every
  platform; methods in docs/model.md.
- Reasoning: strong: each line says how sure, at what size, and what the site may say.
- Interests: ours. Weigh: measured on our crawl; rivals' data and rank mixes differ.

## Findings

- [stats] [ux/uncertainty] Rare champion-roles (under 100 games in 30 days) win far
  under 50% the next week, so a thin rate should shrink to what rare picks win, not to
  50%. `docs/learned.md` ^f1
  > region) won about 39% of its next week's games
  > so a thin rate shrinks not to 50% but to what
- [stats] No counter or duo stands out once thin pairings are pulled to the pack; rare
  picks vary more but symmetrically. ^f2
  > No counter or duo stands far out from the rest: pulling thin pairings to the pack
  > Rare picks differ far more than common ones, but symmetrically: no
- [stats] [ux/uncertainty] Within a champion and role, build options differ far less than
  raw rates suggest; a rune's own games count for little until thousands. ^f3
  > Within one champion and role, options differ in win rate far less than raw
  > A rune's own games count for little until it has thousands (k about 6,000; 600
- [draft] Runes, spells, shards and autofill set in champ select do not detectably change
  the chance of winning on the same champion and role. ^f4
  > 1.5 points either way, within noise. Site: no win claims for runes, spells or
- [data] A rank looked up after the game knows its result: Diamond+ win rate depends on
  when the rank was stored. ^f5
  > The rank we store with each game is looked up after it, so it knows the result: with
  > it a model calls 63.8% of winners instead of 53.7%; Diamond+ wins 50.95% stored in
- [method/dynamics] In a patch's first days last month's numbers predict better than the
  new patch's own games; matchups and duos trail longest. ^f6
  > In a new patch's first days, last month's numbers predict the next week better than
  > the new patch's own games: win rates and items catch up after 2-3 days, matchups,
- [method/dynamics] A new patch does move win rates beyond noise, mostly changed
  champions. ^f7
  > A new patch moves champions' win rates beyond noise, mostly the changed ones: 0.75 pp
- [method/dynamics] Pooling old games with a small per-patch champion offset predicts the
  new patch best from day two (early result). ^f8
  > Across a patch, pooling every old game with a small per-patch champion offset
- [data] Most players have not played a new patch on its first day. ^f9
  > On a patch's first day most players have not played it: 75-89% of players checked
- [data] Builds change with rank but the most played option mostly does not; a thin rank
  slice is mostly a few players. ^f10
  > played option is the same in 78-96% of champion roles. A thin slice is mostly a few
- [draft] Before the lane opponent picks, ranking as if they were average is as good as
  any safer ranking tried. ^f11
  > Before your lane opponent picks, ranking as if they were average is as good as any
