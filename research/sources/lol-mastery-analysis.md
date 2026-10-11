---
title: "Champion Mastery: a statistical analysis of 1M+ games (r/leagueoflegends, Apr 2023)"
url: https://old.reddit.com/r/leagueoflegends/comments/130ucfb/champion_mastery_a_statistical_analysis_of_1m/
kind: thread
commit:
for: [player-tool-needs]
looked: 2026-10-11
depth: docs (post in full; comments skimmed and grepped for one-trick, learning)
relevance: high
grade: B/fair
description: 726-upvote analysis of 1M Gold-ish ranked games by iTero's author; sub-10k mastery wins 44% vs 51.5%, the cliff passes ~12k (~20 games); per-champion learning curves
---
# Champion Mastery: a statistical analysis of 1M+ games (r/leagueoflegends, Apr 2023)

Why: evidence on experience vs counter picking, and what one-tricks and champion
learners could be shown.

## Assessment

- Evidence: B. 726 upvotes, 97% upvoted, 207 comments. 1M+ ranked solo games, patch 13.7,
  NA/EUW/KR, around Gold. Method stated with limitations (smurfs, static mastery).
- Reasoning: strong for a reddit post: explains method, a sanity check, and limits.
- Interests: author is behind iTero (says he will launch the stats on itero.gg), a draft
  tool vendor; the finding supports mastery-aware recommendations.
- Weigh: observational; low-mastery games include smurfs and autofill. The 44% figure is
  stable with what draft-tool users see, but verify on our own data.

## Findings

- [draft] [method] About 20% of players in Gold-ish ranked were on champions with under
  10k mastery; those won about 44% vs 51.5% above 10k. ^f1
  > 20% of players were on Champs they had less than 10k Mastery on.
  > Under 10k Mastery has a 44% win rate vs. 51.5% for over 10k.
- [draft] [method] Mastery, more exactly its lack, was the best predictor of outcome
  among the draft factors the author studied, above counter picks. ^f2
  > Of all the factors I studied, from counter picking to the average Champion win rates, **Mastery** was above and beyond the **best indicator of a game’s outcome**.
- [learning] [method] The win rate crosses 50% around 12,000 mastery, roughly 20 games;
  beyond that gains are slight. ^f3
  > The point at which players moved from below to above 50% win rate was around the **12,000 Mastery** mark.
  > that’s around 20 games of experience before you are no longer dragging down your win chance with the Champion.
- [learning] [method] Per-champion learning curves differ: hardest to pick up (K'Sante,
  Riven, Ivern, Nunu, Yuumi, Senna) and skill ceiling rankings; jungle is most mastery
  sensitive, ADC least. ^f4
  > Jungle had both the lowest win rate when the player was on a low Mastery Champion AND had the highest win rate with high Mastery.
- [method] Players with 1M+ mastery win no more than 50k-1M (51.73% vs 51.77%), read
  as one-tricks stabilising at their true elo. ^f5
  > players on Champion’s with **over 1M Mastery had a 51.73%** win rate, whilst those between **50K-1M had the ever-so-slightly higher value of 51.77%**.
- [learning] [needs] Commenters on one-tricks: they climb on mechanics and champion
  limits but have gaps elsewhere; "what to learn" matters. ^f6
  > Imo it's not about wanting to learn, it's about what to learn. OTPs are good mechanically because thats what they learn, the limits and mechanics of the champion.
- [data] Data limit noted: mastery is a static snapshot, so 10k over two days and 10k
  over five years look the same. ^f7
  > The Mastery data we sourced is a static look at the player, since this is the easiest to get hold of.

## Read

- Post in full; comments skimmed

## Not read

- The linked drafting article; the per-champion spreadsheet
