---
title: 'League of Legends Wiki: Swiftplay (read 2026-10-21)'
url: https://wiki.leagueoflegends.com/en-us/Swiftplay
kind: docs
commit:
for: [frontier-causal]
looked: 2026-10-21
depth: docs (intro, Lobby, Loadout selection)
relevance: high
grade: B/fair
description: Community wiki page on Swiftplay (queue 480): champions and roles are chosen in the lobby before queueing, no champion select, faster game rules; replaced Quickplay, which had replaced Blind Pick
---
# League of Legends Wiki: Swiftplay

Why: a queue where champions are fixed before the opponents are known removes the
counter-pick response entirely: a candidate natural experiment for matchup effects.

## Assessment

- Evidence: B. Community wiki, sourced to Riot posts and patch notes; current.
- Reasoning: fair (descriptive).
- Interests: none.
- Weigh: the mechanism is reliable; whether match-v5 serves 480 games today is open
  ([[gh-devrel-1068]], [[match-v5-queues-measured]]).

## Findings

- [method/causal] [queues] Swiftplay players skip champion select: they choose champions
  in the lobby before queueing, so no pick can respond to the enemy or to teammates'
  final picks. ^f1
  > Players also skip [champion select](https://wiki.leagueoflegends.com/en-us/Champion_select "Champion select") by making their selections beforehand in the lobby.
- [method/causal] [queues] Each solo player names two roles (one a Priority role) with a
  champion for each; the matchmaker decides which they get. ^f2
  > the player selects two roles with one of them strictly being a Priority role
- [method/causal] [queues] Different game: special rules make matches much shorter, and
  it is a normal (unranked) queue. ^f3
  > presents special game rules meant to accelerate the game's progression and result in significantly shorter matches
- [method/causal] [queues] New players start on their two highest-mastery champions, so
  Swiftplay picks lean even more toward comfort than ranked. ^f4
  > the game automatically assigns the player to their two highest [mastery](https://wiki.leagueoflegends.com/en-us/Champion_Mastery "Champion Mastery") champions
- [method/causal] (inferred) Comparing a lane matchup's effect in Swiftplay (no counter
  response) with ranked draft (later picker sees the opponent) bounds how much of a
  ranked matchup win rate is counter-pick selection. Confounded by population (casual,
  mixed ranks), faster game rules and lack of role-based champion pools; usable only for
  the sign and rough size, on matchups common in both, and only if 480 is served. ^f5

## Read

- Intro, Lobby, Loadout selection.

## Not read

- In-game rule details (minion frenzy, death timers, sudden death).
