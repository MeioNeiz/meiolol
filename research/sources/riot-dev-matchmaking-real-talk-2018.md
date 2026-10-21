---
title: '/dev: Matchmaking real talk (Riot, 2018)'
url: https://www.leagueoflegends.com/en-gb/news/dev/dev-matchmaking-real-talk/
kind: article
commit:
for: [frontier-ceiling]
looked: 2026-10-21
depth: docs (matchmaking answers)
relevance: high
grade: B/fair
description: Riot designers' Q&A on matchmaking; states the target that most teams have a 50 +/- 1% expected win rate, and names what the matchmaker cannot see
---
# /dev: Matchmaking real talk (Riot, 2018)

Why: how much pre-game predictability does Riot's matchmaker try to remove, in Riot's
own words?

## Assessment

- Evidence: B. First-hand from Riot's matchmaking designers (Riot Gortok and others),
  2018; a player-facing post, no data shown.
- Reasoning: fair. Explains limits honestly; no numbers beyond the target.
- Interests: Riot wants players to trust matchmaking.
- Weigh: the 50 +/- 1% is the matchmaker's own estimate from MMR, before champion
  select; it says nothing about how predictable the game is from what the matchmaker
  does not use.

## Findings

- [method/ceiling] Riot's matchmaker gives most teams an expected win rate within
  50 +/- 1% by its own model. ^f1
  > Within the actual systems, most teams have an expected win rate of 50 +/-1%.
  > We expect every game you play to have a 50 +/-1% chance of your team destroying the Nexus.
- [method/ceiling] Named blind spots: unfamiliar positions or champions, premade MMR
  gaps, unconverged ratings (smurfs), and personal factors. ^f2
  > What if players are playing positions or champions they aren’t familiar with?
  > a player hasn’t played enough games to get an accurate rating (looking at you, smurfs)?
- [method/ceiling] Riot designs for snowballing: small early advantages are meant to
  decide games, a source of in-game variance no pre-game model sees. ^f3
  > we want League to be a game where getting a small advantage and running with it is one path to victory.
- [method/ceiling] (inferred) Matchmaking runs before champion select, so draft signal
  is untouched by it, while the skill signal it uses (MMR) is removed: pre-game
  predictability left over is the draft plus what MMR misses (champion and role
  experience, unconverged ratings, form), which matches player features adding most
  in [[draft-predictor-methods]] C11. ^f4

## Read

- The matchmaking and imbalance answers.

## Not read

- Answers on honour, ranked tiers and position select.
