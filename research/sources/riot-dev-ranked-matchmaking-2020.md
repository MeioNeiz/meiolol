---
title: "/dev: Ranked and Matchmaking in 2020 (Riot Codebear, 2020-02-28)"
url: https://www.leagueoflegends.com/en-us/news/dev/dev-ranked-and-matchmaking-in-2020/
kind: article
commit:
for: [draft-predictor-methods]
looked: 2026-10-12
depth: docs (whole post)
relevance: medium
grade: A/fair
description: Riot's competitive product lead on 2020 matchmaking: autofill balance and duo balance across teams, position proficiency not measured by MMR
---
# /dev: Ranked and Matchmaking in 2020 (Riot Codebear, 2020-02-28)

Why: which pre-game player features does LoL's matchmaker already equalise between teams
(so a predictor gains little from them), and which does it ignore?

## Assessment

- Evidence: A. Riot's own product lead describing the live matchmaker.
- Reasoning: fair. Plans, no numbers.
- Interests: Riot presenting its own improvements.
- Weigh: trust what the matchmaker balances; the effect sizes are not given here.

## Findings

- [method] Riot balances the number of autofilled players and of premades per team. ^f1
  > **Autofill Balance** - As announced in Season Start, these updates aim to balance the number of autofilled players on each team.
  > **Duo Balance** - This update aims to balance the number of premades on each team.
- [method] Riot says position proficiency matters a lot, and that MMR does not measure a
  player per position. ^f2
  > Though our current system does not specifically measure you against all potential positions, we do understand that position proficiency has a significant impact on the game.
- [method] Rank and hidden MMR are known to diverge. ^f3
  > The hidden relation between player’s visible ranks and matchmaking rating has been causing confusion and frustration
- [method] (inferred) For a predictor: team MMR, autofill count and premade count are
  roughly equalised by design, so they add little as team totals; what can add is what the
  matchmaker ignores: who is autofilled into which role, and champion and role proficiency
  ([[moba-cupid-rematchmaking#^f7]]). ^f4
- [data] (inferred) Riot API: MMR is hidden; league-v4 gives current tier, division and LP
  only (not at game start), so rank at game time needs snapshots taken near it.
  match-v5 has no general party flag (the schema's only premade fields,
  wasPremadeWithSevereTransgressor and wasPremadeWithIGNBGameEndCauser, are tied to
  game-ruining players) and no autofill flag; both must be inferred (repeated co-play;
  teamPosition against the player's usual roles). ^f5

## Read

- Whole post

## Not read

- The promised follow-up with autofill and premade balance results
