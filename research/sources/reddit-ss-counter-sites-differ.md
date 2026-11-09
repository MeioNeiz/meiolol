---
title: 'r/summonerschool: Why such differing data on champ counters? (Dec 2022)'
url: https://old.reddit.com/r/summonerschool/comments/zqq5wi/why_such_differing_data_on_champ_counters/
kind: thread
commit: 
for: [champselect-advice-methods]
looked: 2026-11-06
depth: docs (whole thread, redlib mirror)
relevance: medium
grade: C/fair
description: 76-point thread asking why stats sites list different counters on the same sample; replies name rank mix, base win rate, counter definitions and thin matchups
---
# r/summonerschool: Why such differing data on champ counters? (Dec 2022)

Why: players notice counter lists disagree between sites; what reasons do they give, and what
do they trust?

## Assessment

- Evidence: C. One thread, 76 points, 97% upvoted, about 43 comments; replies are players'
  explanations, some wrong or unsourced (Riot "confirmed" claims are disputed in-thread).
- Reasoning: fair. The best replies name real confounders (rank mix, base win rate, definition
  of counter, small matchup samples).
- Interests: none known.
- Weigh: a reception signal for "sites disagree" and for which explanations players accept;
  not evidence of how any site computes counters.

## Findings

- [needs] [ux/trust] Complaint: the main sites sometimes list radically different counters for
  the same champion on supposedly the same sample. Post (76 points, 97% upvoted) ^f1
  > sometimes they will list radically different results as counters or losing matchups for a given champion, even when each site is allegedly looking at the same sample
- [method/causal] Top explanation (58 points): rank mix between two champions' players
  exaggerates a matchup, and a raw matchup win rate ignores each champion's base win rate. ^f2
  > the data is distorted because every garen vs GP game is a plat IV GP playing vs a Gold II garen
  > if the average Ryze winrate is 45% and the average Sett mid winrate is 52%, then it's probably the case that Ryze is really really good against Sett.
- [draft] Sites define "counter" differently (win rate, gold difference at 15), and nobody
  says how big an edge makes a counter. ^f3
  > Different places and people use different definitions, U.gg for example uses overall winrates and Gold Difference at 15, but is 55% winrate against someone what you would consider a counter?
- [stats] Thin matchups named as a cause: so many champion pairs that a given matchup's sample
  may be small. ^f4
  > So a sample for a certain matchup might be small and unreliable.
- [ux/trust] Trust goes to the site seen as transparent and used by Riot designers (Lolalytics),
  and to its delta 2 measure (matchup win rate against both champions' normalised rates). ^f5
  > I tend to prefer lolalytics because they're more transparent about how they arrive at their numbers, which is key to interpreting them.
  > It takes the counter winrate - the normalised champion win rate.
- [stats] Normalisation confuses: Lolalytics shows raw rank win rates (high ranks above 50%)
  while U.GG is said to centre each rank on 50%, so the same champion reads differently. ^f6
  > No rank will have a flat 50% winrate.
- [needs] The comfort pick view returns: don't first-time a counter in ranked because a site
  says it counters (downvoted to -15 for its tone, but the OP's reply grants the point). ^f7
  > don't use those trash ass websites to decide what champion you're going to first time in ranked just because it counters the champion the enemy picked.

## Read

- Whole thread as served by the redlib mirror (all visible comments)

## Not read

- Linked posts on U.GG normalisation
