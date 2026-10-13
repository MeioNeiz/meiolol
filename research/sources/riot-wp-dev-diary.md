---
title: 'Riot 2023: Dev Diary, Win Probability powered by AWS at Worlds'
url: https://lolesports.com/en-US/news/dev-diary-win-probability-powered-by-aws-at-worlds
kind: article
commit:
for: [effect-isolation]
looked: 2026-10-13
depth: docs (whole post)
relevance: medium
grade: B/fair
description: Riot esports product post on its broadcast win probability model for pro games (xgboost on game time, gold share, XP, alive players, towers, dragons and soul, herald, inhibitor and buff timers); WPA named as a future step
---
# Riot 2023: Dev Diary, Win Probability powered by AWS at Worlds

Why: Riot's own in-game win model for LoL; which state features it uses (especially for
objectives) and how it frames event impact.

## Assessment

- Evidence: B. Riot's official model on every pro broadcast since MSI 2023; trained on all
  pro games since patch 10.4. No accuracy or calibration numbers published.
- Reasoning: fair. Explains why win probability beats gold difference; no validation.
- Interests: product and sponsor (AWS) marketing.
- Weigh: trust the feature list as what Riot thinks matters; pro play, not solo queue.

## Findings

- [method] Pro win model is xgboost over game state: side, game time, gold share, team
  XP, players alive, towers, dragons and soul, herald in inventory, inhibitor respawn
  timers, Baron and Elder buff timers and players carrying them. ^f1
  > Our WP stat is developed using a [machine learning][1] (ML) algorithm called xgboost
  > Inhibitor timers (how long until an inhibitor respawns) for each inhibitor - Baron timers (time until Baron buff expires for the team) - Elder timer (time until Elder Dragon buff expires for the team)
- [method] Objectives enter as live state (buff time left, inhibitor respawn) rather than
  as counts, so an objective's value fades as its effect expires. ^f2
  > Baron timers (time until Baron buff expires for the team)
- [data] Trained on all professional games since patch 10.4 and retrained with new
  results to follow the meta. ^f3
  > The current version was trained using all professional LoL Esports games since patch 10.4 (early 2020).
- [method] Gold difference understates objectives: at a 10k lead, Baron moves gold by
  about 1.5k, but the buff is worth more than its gold, which win probability shows. ^f4
  > In a game where there is already a large GD (ex: 10k+ GD) and a team gets Baron, the GD graph changes by just 1.5k gold
  > the WP graph would show a more discernible change if the team behind in gold got Baron as Baron buff is more meaningful than just the 1.5K gold spike
- [method] Not yet in the model: team comp strength and scaling, individual dragon types;
  WPA per event named as a possible next step. ^f5
  > Team comp data (strength & scaling) - Micro interactions in team-fights - Individual dragons taken and type of dragon souls
  > WPA quantifies the percent change in a team's chances of winning from one event to the next.
- [method] (inferred) For a gold equivalent of an objective, its direct gold bounty is a
  floor; the value worth reporting is win points added converted at the local
  win-per-gold slope, which includes the buff and map effects. ^f6
- [method] (inferred) Our state model should carry buff and inhibitor timers (derivable
  from timeline event timestamps) as well as counts, or Baron's value gets smeared into
  the following minutes' gold and towers. ^f7

## Read

- Whole post
