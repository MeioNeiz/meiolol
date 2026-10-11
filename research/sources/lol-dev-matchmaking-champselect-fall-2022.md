---
title: Matchmaking and Champion Select - Fall 2022 (Riot dev blog, 2022-09-30)
url: https://www.leagueoflegends.com/en-us/news/dev/matchmaking-and-champion-select-fall-2022/
kind: article
commit:
for: [riot-production-key]
looked: 2026-10-11
depth: skimmed (Recent updates section)
relevance: high
grade: A/strong
description: Riot Game Loop team dev blog; why champ select anonymity exists, dodging motives, Riot's own loadout recommender
---
# Matchmaking and Champion Select - Fall 2022 (Riot dev blog, 2022-09-30)

Why: Riot's own stated philosophy for champion select, which a pick recommender must fit.

## Assessment

- Evidence: A. Official dev blog by Riot Auberaun (Game Loop team), 30 Sep 2022.
- Reasoning: strong. Explains motives, trade-offs, admits legitimate dodges.
- Interests: Riot.
- Weigh: design intent, not policy text; four years old but the anonymity it describes
  is still live per later policy (riot-champ-select-anon-apps-1222).

## Findings

- [policy] [draft] Riot sees third-party teammate info in champ select as causing wrong
  conclusions and pressure, e.g. forcing highest-winrate champion picks. ^f1
  > Today, a lot of players use external websites and third-party apps that provide all sorts of information about their teammates. With this information, players are drawing conclusions that aren’t necessarily correct and pressuring their teammates into things that they might not want to do, like picking the exact same champion every game because it’s their highest winrate or most played.
- [policy] [draft] Riot does not want lobby-player metagaming or dodging when the setup is
  imperfect. ^f2
  > We think the best version of League is not one where you metagame based on the players in your lobby, weigh who’s on a win or loss streak or playing a different champion, and dodge or pressure others to dodge when your setup doesn’t meet perfect conditions.
- [policy] Riot wants to reduce dodging frequency by changing its motives. ^f3
  > We want to impact the motivations behind why dodging occurs to reduce the frequency in a natural way.
- [ux] [tools] Riot itself planned champ select recommendations (runes, Summoner Spells),
  citing players going to external sites for this. ^f4
  > we want to provide rune and Summoner Spell recommendations during champ select.
  > this should be helpful for more veteran players who might currently go to external websites or apps to learn what to take on a champion they’re not familiar with.
- [policy] (inferred) Champion-level recommendations in champ select align with Riot's own
  direction; dodge advice and per-teammate stats cut against it. ^f5
- [policy] Checked, not there: nothing on champion pick recommendation or draft win
  probability as such. ^f6

## Read

- intro and Recent updates section

## Not read

- matchmaking and queue sections later in the post
