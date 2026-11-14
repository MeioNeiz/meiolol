---
title: 'Kwak 2026: When the Rule-Maker Runs the World Championship: Late Patches and Procedural Accountability in League of Legends (arXiv 2610.07427)'
url: https://arxiv.org/html/2610.07427
kind: paper
commit: 
for: [early-patch-forecast]
looked: 2026-11-14
depth: docs (abstract, 3.2 coding, 4.3 outcome result, 6 limitations, Appendix B coding and checks; governance sections skipped)
relevance: high
grade: C/strong
description: Preprint (Oct 2026) that has an LLM code 1,090 champion changes in 40 pre-Worlds patches as buff or nerf with a 1-3 size, validates the codes three ways, and finds team exposure to the coded changes does not clearly predict Worlds wins
---
# Kwak 2026: When the Rule-Maker Runs the World Championship: Late Patches and Procedural Accountability in League of Legends (arXiv 2610.07427)

Why: the closest thing found to "parse patch notes into a signed size, then test it
against outcomes" on League: how reliable is LLM coding of patch notes, and did the
coded size predict anything?

## Assessment

- Evidence: C. Single-author preprint, a month old, not peer reviewed; but 10 Worlds,
  1,097 games, 1,090 coded changes, a human-coded sample, a re-code and a game-data
  check, a power simulation, code and codes said to be public.
- Reasoning: strong. Reports the null with its interval and power, lists what the
  coding cannot see, reruns under three alternative codings.
- Interests: none known (academic; argues for governance reform, which the null
  outcome result does not help).
- Weigh: trust the coding reliability numbers (direction good, magnitude weaker, items
  and runes poor). The outcome test is pro play through team exposure, not a champion's
  solo queue win rate: it says nothing either way about our 16.23 prior, except that a
  1-3 size scale has never been shown to carry outcome signal.

## Findings

- [method/dynamics] [method/pretrain] Scheme: per champion and patch, one net judgment
  from the patch-note text: buff, nerf, adjustment, rework or bug fix, and for buffs
  and nerfs a size 1-3; signed score = plus or minus the size. 3.2, Appendix B ^f1
  > "Each change was coded for direction (buff, nerf, adjustment, rework, or bug fix) and for magnitude from 1 to 3."
- [method/dynamics] Size rule: 1 is about one number and under 10% of one ability or
  stat, 2 several numbers or a core ability or base stat, 3 a multi-part change meant
  to move viability. Appendix B ^f2
  > "magnitude as 1 for small changes, roughly one number and under 10% of one ability or stat"
- [method/pretrain] [stats] Direction is reliable: LLM vs the author on 120 changes
  87.5% (sign 89.2%, kappa 0.84); a second LLM run on 309 pairs 99.4%; against game
  data where values moved one way, 94.9% of 450. 3.2 ^f3
  > "Direction agreed in 87.5% and the sign in 89.2% (Cohen’s κ=0.84)"
  > "the coded sign matched it in 94.9% of 450 changes"
- [method/pretrain] [stats] Magnitude is weaker: where both coders agreed on buff or
  nerf, the size matched exactly in 75%, and the 1-2-3 spacing is assumed, not
  validated. Appendix B, 6 ^f4
  > "magnitude agreed exactly in 75% and within one level in all"
  > "Magnitude codes are less reliable than directions, and agreement does not validate their assumed spacing"
- [method/dynamics] Item, rune and system changes could not be coded reliably per
  champion, so exposure uses direct champion changes only. 3.2 ^f5
  > "independent coders agreed on their direction in only 52–71% of cases, because which champions such a change helps or hurts must often be inferred"
- [data] Game data miss changes the notes state: of 977 comparable changes, 39 coded
  buffs and 17 coded nerfs show no changed value in Data Dragon or CommunityDragon
  (Table 5), and Data Dragon has no passives. Appendix B ^f6
  > "cannot see changes the game data do not record, such as passive abilities in Data Dragon"
- [method/dynamics] The codes track behaviour: at Worlds, buffed champions rose 7.8 pp
  in pick-and-ban presence and nerfed ones fell 12.6 pp (r 0.42 between score and
  presence change, n 504). 3.2 ^f7
  > "those coded as buffed rose in pick-and-ban presence at Worlds relative to the preceding regional games by 7.8 pp on average, and nerfed champions fell by 12.6 pp"
- [method/dynamics] [stats] But the coded exposure does not clearly predict wins: a
  team's net exposure is worth +1.3 pp per SD, interval -0.9 to +3.7 (1,097 games);
  the test could only see about 3.4 pp per SD or more. 4.3 ^f8
  > "Net exposure is associated with +1.3 pp in win probability per SD, with a 95% event-bootstrap interval from −0.9 to +3.7"
- [method/dynamics] Nerfs land on the most-contested champions and buffs on the less
  contested: 52% of the top presence decile nerfed, 1% buffed. 4.1 ^f9
  > "In the most-contested decile, 52% of champions were nerfed and 1% buffed."
- [method/dynamics] Checked, not there: no champion-level win rate before and after a
  coded change, no solo queue data, no forecast of a champion's move from its score;
  the outcome test is team-level in pro play only. ^f10
- [method/dynamics] (inferred) For a 16.23 test: an LLM (or we by hand) can label each
  champion change buff or nerf with a 1-3 size from Riot's notes, reproducibly and
  before any games, and it sees what Data Dragon hides (16.21's Hubris). Whether sign
  x size predicts the win-rate move is untested anywhere; items and runes need our
  exposure-by-build weights (PT7), not a coder's guess. ^f11

## Read

- Abstract, 3.2, 4.1 (first paragraphs), 4.3, 6 Limitations, Appendix B.

## Not read

- Sections 4.2, 4.4, 5 (bans, team cases, governance); Appendix C-I; the replication
  repository (coded patch notes 2016-2025: a ready change list with sizes, if we ever
  backfill older patches).
