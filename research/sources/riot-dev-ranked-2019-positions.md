---
title: '/dev: Addressing Your Feedback on Ranked for 2019 (Riot SapMagic, 2018-06)'
url: https://web.archive.org/web/2019/https://nexus.leagueoflegends.com/en-us/2018/06/dev-addressing-your-feedback-on-ranked-for-2019/
kind: docs
commit:
for: [pregame-player-skill]
looked: 2026-10-13
depth: docs (whole post, archived copy)
relevance: medium
grade: B/fair
description: Riot's Ranked lead on the 2019 position ranks design; per-position MMRs linked to each other, a new position seeded from the others, link tightened on suspected role trading; no data
---
# /dev: Addressing Your Feedback on Ranked for 2019 (Riot SapMagic, 2018-06)

Why: Riot's own design for per-position skill in LoL: separate ratings, one rating plus
offsets, or something linked between them?

## Assessment

- Evidence: B. First-hand from Riot's Ranked lead; a design statement, not a
  measurement; the position ranks it describes were withdrawn in March 2019
  ([[riot-dev-state-of-ranked-2019]]), positional matchmaking kept.
- Reasoning: fair. Explains the abuse cases (role trading) and the fix; no numbers on
  how much position skill differs.
- Interests: Riot defending a change players disliked.
- Weigh: trust the structure (per-position MMRs pooled toward each other); the LP
  numbers are product tuning, irrelevant to us.

## Findings

- [method] Per-position MMRs are linked: a new position starts from the player's other
  positions' MMRs, so a Gold mid trying top lands in Silver games, not Bronze. ^f1
  > Imagine you're a Gold mid main. If you decide to go play a new position like top, matchmaking will look at your MMR in mid and other positions to estimate your initial skill.
  > That means instead of getting put into a Bronze game, you'll likely play a Silver game.
- [method] The link has slack that tightens when Riot is less confident about the
  position played (repeated swaps or suspected trades), pulling off-role MMR toward
  the main. ^f2
  > To start, that link has some slack, but we tighten it if we're less confident about the position you're playing.
- [method] Off-role skill is below main-role skill by about one tier in their example
  (Gold main, Silver off-role start). ^f3
  > you'll likely play a Silver game.
- [method] Before 2019, matchmaking ignored position skill entirely. ^f4
  > those games should be about the same quality as today because we don't currently consider position skill in matchmaking.
- [method] Off-role and autofill games still move the main position (LP splashing):
  every game is treated as evidence about one underlying skill. ^f5
  > Win or lose, every game reflects your skill and _needs to matter_ regardless of the position or champion you're playing.
- [method] (inferred) This is the TrueSkill2 base-plus-offset structure
  ([[trueskill2-2018#^f11]]) applied to positions: one base skill, a per-position offset
  shrunk toward it when evidence is thin. For us the same holds per champion: player
  base (rank at start, overall recent results) plus a champion offset shrunk by games
  on that champion; off-role (a role the player rarely plays in our history) as a
  negative offset of roughly a tier. ^f6

## Read

- Whole post (archived 2019-11 copy)

## Not read

- Post 1 (/dev: Updates to Ranked for 2019) and the boards recap
