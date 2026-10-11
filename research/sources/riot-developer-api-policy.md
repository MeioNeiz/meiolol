---
title: League of Legends Developer API Policy (Riot DevRel support site)
url: https://support-developer.riotgames.com/hc/en-us/articles/22698698001939-League-of-Legends
kind: docs
commit:
for: [riot-production-key]
looked: 2026-10-11
depth: skimmed (policy sections only)
relevance: medium
grade: A/fair
origin: riot-docs-lol
description: DevRel help-centre copy of the League developer policy; mirrors developer.riotgames.com/docs/lol
---
# League of Legends Developer API Policy (Riot DevRel support site)

Why: check whether the help-centre copy adds anything on champ select or AI beyond docs/lol.

## Assessment

- Evidence: A. Riot DevRel help centre; page says "1 year ago Updated" (so about late
  2025). Content matches riot-docs-lol, hence `origin`.
- Reasoning: fair.
- Interests: Riot.
- Weigh: confirms docs/lol text is the current policy; adds nothing new on champ select,
  win rates (beyond Arena) or AI.

## Findings

- [policy] Help-centre copy of the League policy, updated about a year before 2026-10-11. ^f1
  > 1 year ago Updated
- [policy] Production keys are for larger, professional projects; Riot judges use case
  and ability to deliver. ^f2
  > Production keys are meant for larger-size, professional projects.
  > Does the developer show they will deliver on that use case?
- [policy] Unapproved: game-session-specific info previously unknown to the player; apps
  that dictate player decisions. ^f3
  > Products may not provide any game-session-specific information that would be previously unknown to the player.
  > Apps that dictate player decisions.
- [policy] Game integrity: no info not present in the client that gives an edge, e.g.
  enemy ultimate cooldown tracking. ^f4
  > Products must not use or incorporate information not present in the game client that would give players a competitive edge (e.g., automatically or manually allowing tracking enemy ultimate cooldowns)
- [policy] Win-rate ban is specific to Augments and Arena items, not champions. ^f5
  > Products cannot display win rates for Augments or Arena Mode items.
- [policy] Checked, not there: no mention of champion select specifically, pick
  recommendation, dodging, AI, machine learning or model training. ^f6

## Read

- Developer API Policy, Game Integrity, Game Policy use cases

## Not read

- API reference sections (RSO, tournaments, Data Dragon): covered by riot-docs-lol
