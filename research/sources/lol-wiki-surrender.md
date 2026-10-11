---
title: 'League of Legends Wiki: Surrendering'
url: https://wiki.leagueoflegends.com/en-us/Surrender
kind: docs
commit:
for: [curve-statistics-method]
looked: 2026-10-11
depth: listed (whole page)
relevance: medium
grade: B/fair
description: Community wiki page on surrender, AFK surrender and remake rules, i.e. when Summoner's Rift games can end early
---
# League of Legends Wiki: Surrendering

Why: when can a ranked game end before the laning phase is over? Sets where per-minute
curves stop being a full sample (survivorship).

## Assessment

- Evidence: B. Official community wiki (Fandom successor hosted by Riot's wiki domain),
  maintained by editors; rules match common player knowledge.
- Reasoning: fair. Rules stated with history, cites Riot's remake FAQ.
- Interests: none.
- Weigh: verify against our own data (duration histogram, gameEndedInSurrender and
  gameEndedInEarlySurrender flags in match-v5) rather than trust exact thresholds.

## Findings

- [data] On Summoner's Rift no surrender before 15 minutes; votes need 4 of 5 or 70%. ^f1
  > On [Summoner's Rift](https://wiki.leagueoflegends.com/en-us/Summoner%27s_Rift "Summoner's Rift"), surrenders cannot be called before the 15 minute mark.
  > At least 4 out of 5 players **or** 70% of the team must agree to surrender in order for the vote to pass
- [data] Exception: with an AFK teammate a unanimous surrender is possible after 3:30. ^f2
  > If a player is AFK, that player's team can surrender at any point after 3 minutes and 30 seconds of game time with a **unanimous** vote
- [data] Remakes (a player idle 55 s within the first 2:25) end the game with no win or
  loss for the others. ^f3
  > If a player either disconnects or is idle or within the spawn for 55 consecutive seconds within the first 2 minutes and 25 seconds of the game, then the other members of the team can issue a `/remake` vote that ends the game in a tie
- [data] A failed vote blocks another for three minutes; the original threshold was 20
  minutes before the 15-minute option existed. ^f4
  > cannot be initiated again for another three minutes of game time.
  > The original wait time to initiate a surrender vote on Summoner's Rift was 20 minutes before adding in the early surrender option of 15 minutes.
- [data] [stats] (inferred) So curves to minute 14 are close to a full sample (only
  AFK games end early, and those should be dropped anyway); from 15 on, games that
  are lost badly drop out, and the surviving games at minute 20+ are biased toward
  closer lanes. Curves past 15 must be read as "among games still running". ^f5

## Read

- Whole page
