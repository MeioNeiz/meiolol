---
title: "Apps that reveal player names or stats in Champ Select must remove them from 12.22 (Riot DevRel via devtrackers, 2022)"
url: https://devtrackers.gg/leagueoflegends/p/749a443a-apps-that-reveal-player-names-or-stats-in-champ-select-need-to-remove-these-informations-starting-patch-12-22
kind: thread
commit:
for: [riot-production-key]
looked: 2026-10-11
depth: docs (whole thread capture)
relevance: high
grade: B/fair
description: Reddit thread quoting Riot DevRel's 2022 policy that ranked solo/duo champ select apps must not show player names or stats, with Riot staff replies
---
# Apps that reveal player names or stats in Champ Select must remove them from 12.22 (Riot DevRel via devtrackers, 2022)

Why: the most specific Riot ruling on what champ select tools may show.

## Assessment

- Evidence: B. Devtrackers capture of a Reddit thread (Nov 2022, "almost 4 years ago")
  quoting a @RiotGamesDevRel tweet, with replies from Riot DevRel staffer u/Auberaun
  (devtrackers only tracks Riot accounts). Secondhand for the tweet; first-hand for the
  replies. Not re-verified against X.
- Reasoning: fair. Staff replies explain the why (champ select toxicity and dodging).
- Interests: Riot.
- Weigh: 2022 policy, still reflected in Overwolf compliance docs per search results;
  treat as current unless contradicted.

## Findings

- [policy] [ux] From patch 12.22, apps must not reveal player names or stats in Ranked
  Solo/Duo champ select. ^f1
  > Apps that reveal player names or stats in Champ Select will be asked to remove this feature immediately. This specifically applies only to Ranked Solo/Duo
- [policy] Riot DevRel: the data is obfuscated in the API anyway; rule is against
  circumvention. ^f2
  > To be clear it's already going to be obfuscated in the API whether apps change stuff or not, we just don't wanna see any funny business / circumvention.
- [policy] Asked whether data is removed from the LCU generally or only hidden in queue
  420 lobbies, Riot staff answered "the latter" (queue-specific obfuscation). ^f3
  > Will it be removed generally from LCU or just specifically not show the data anymore if it is a queue 420 lobby?
- [policy] Player labels and stats can be shown from the loading screen, not in champ
  select. ^f4
  > You won't be able to see those in champion select but you will as soon as you hit the loading screen.
- [policy] [draft] Rationale: in champ select players have an incentive to pressure
  teammates or incite dodges; Riot staff even muses about removing dodging. ^f5
  > In Champion Select when you can see something you don't like you have an incentive to try to change their behavior to what you want, or incite them or others to dodge.
  > What are the impacts if we removed dodging entirely?
- [policy] (inferred) A pick recommender that uses only champion-level data (picks, bans,
  roles, aggregate stats) fits this rule; using per-player history of allies or enemies
  in ranked solo/duo champ select, or dodge advice based on teammates, would not. ^f6

## Read

- whole capture (original post and Riot staff replies)

## Not read

- the original @RiotGamesDevRel tweet (X needs JS)
- the Oct 2022 LoL dev post on Champ Select Anonymity
