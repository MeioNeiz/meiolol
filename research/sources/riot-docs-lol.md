---
title: Riot Developer Portal League of Legends docs (API policy, Game Policy, RSO, LCU)
url: https://developer.riotgames.com/docs/lol
kind: docs
commit:
for: [riot-production-key]
looked: 2026-10-11
depth: docs (Developer API Policy, Game Policy, RSO, League Client API sections)
relevance: high
grade: A/fair
description: League-specific policy, production key use cases, unapproved use cases, RSO and LCU notes
---
# Riot Developer Portal League of Legends docs

Why: League-specific rules for a champ select recommender, and what Riot evaluates for production keys.

## Assessment

- Evidence: A. Canonical Riot docs (snapshot 2026-10-11, Data Dragon link at 16.20.1).
- Reasoning: fair. Lists, few explanations.
- Interests: Riot.
- Weigh: "Apps that dictate player decisions" is the line a "best pick" tool must stay clear of.

## Findings

- [policy] LoL-specific boilerplate wording differs slightly from general policies. ^f1
  > [Your Product Name] is not endorsed by Riot Games and does not reflect the views or opinions of Riot Games or anyone officially involved in producing or managing Riot Games properties. Riot Games and all associated properties are trademarks or registered trademarks of Riot Games, Inc
- [policy] Any product serving players must be registered, even if it uses no official APIs. ^f2
  > If your product serves players, you must register it with us regardless of whether or not your product uses official documented APIs.
- [policy] No data brokering between Riot API and other companies. ^f3
  > No apps serving as a “data broker” between our API and another third-party company.
- [policy] LoL game integrity adds: no info not in the client that gives a competitive edge. ^f4
  > Products must not use or incorporate information not present in the game client that would give players a competitive edge
- [policy] LoL game integrity: cannot analyse players deliberately hidden by the game. ^f5
  > Products cannot identify or analyze players who are deliberately hidden by the game.
- [policy] Production key evaluation: two factors, use case and ability to deliver. ^f6
  > Riot analyzes two main factors when evaluating applications:
  > Is the use case good and approved?
  > Does the developer show they will deliver on that use case?
- [policy] A prototype or even mockups/deck can suffice; a working link showing user flow is required. ^f7
  > Prototype that is mostly testable by Riot.
  > Mockups where Riot can clearly express your intent and the user flow.
  > You must also send a link to a working site, mockup, prototype, or rendering where it is easy to understand the user flows of the tool.
- [policy] Production keys for larger, professional projects. ^f8
  > Production keys are meant for larger-size, professional projects.
- [policy] Approved examples include aggregate stats and overlays with static pre-game data. ^f9
  > Game overlays that provide static data that is available prior to the game.
  > Aggregate player stats (no specific players).
- [policy] Unapproved: apps dictating player decisions; game-session-specific info unknown to player. ^f10
  > Apps that dictate player decisions.
  > Products may not provide any game-session-specific information that would be previously unknown to the player.
- [policy] Unapproved: win rates for Augments or Arena items. ^f11
  > Products cannot display win rates for Augments or Arena Mode items.
- [policy] RSO requires a production key; Riot initiates RSO after approval. ^f12
  > This access is only available to developers with Production Level API Keys.
  > If approved, we will contact you in the developer portal app messaging to kick off the RSO integration process.
- [policy] LCU is unsupported; Riot wants a new app or a note on the existing app listing endpoints used. ^f13
  > This service is not officially supported for use with third party applications.
  > Either [create a new application](https://developer.riotgames.com/app-type) or leave a note on your existing application in the Developer Portal.
- [policy] Checked, not there: no champ select specific rule, no dodge rule, no mention of ML/AI training. ^f14

## Read

- Developer API Policy, Game Policy, RSO Integration, League Client API sections

## Not read

- Data Dragon, tournament, Game Client API sections (not relevant)
