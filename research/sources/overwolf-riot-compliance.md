---
title: 'Overwolf Electron: Riot Games compliance guidelines'
url: https://dev.overwolf.com/ow-electron/guides/game-compliance/riot-games
kind: docs
commit: 
for: [riot-production-key]
looked: 2026-10-11
depth: docs (whole page)
relevance: high
grade: B/fair
description: Overwolf's relay of Riot's rules for LoL/TFT/Valorant apps on its platform (hosts Porofessor, Blitz-style overlays)
---
# Overwolf Electron: Riot Games compliance guidelines

Why: Overwolf hosts most commercial LoL companion apps; its compliance page is how Riot's feature bans reach those tools, and states what approval it demands.

## Assessment

- Evidence: B. Platform operator's developer docs, current 2026; second-hand relay of Riot rules, not Riot itself.
- Reasoning: fair. Rules with occasional reasons ("metagaming and queue dodging").
- Interests: Overwolf (platform, needs Riot's goodwill).
- Weigh: good indicator of what Riot enforces through platforms; check the Riot originals where wording matters.

## Findings

- [policy] Any app integrating with a Riot game needs Riot approval through the developer portal, even without using the Riot API; Overwolf asks for it before publishing. ^f1
  > If you wish to integrate your app with any of Riot’s games, you are required to seek their approval through their 3rd party application process.
  > These guidelines hold even if you do not intend to use the Riot API itself. Do note that apps which reach the publication phase and do not yet possess a Riot approval will be asked to provide one before proceeding.
- [policy] Apps must show the "isn't endorsed" line and not claim Riot approval or endorsement. ^f2
  > Riot asks that you ensure that your standard messaging (below) is located somewhere that users can see it and doesn’t mention their approval or endorsement of your app.
- [policy] [ux] Ranked Solo/Duo champ select: non-party summoner names must be shown as Ally 1, Ally 2..., to prevent metagaming and queue dodging. ^f3
  > Riot Games is working to prevent metagaming and queue dodging (among other things). As such apps should make sure that Summoner Names in `Ranked Solo/Duo` champion select should be obfuscated.
  > All instances of non-party Summoner Names in Champion Select should be replaced with `Ally #`
- [policy] Prohibited in-game: notifications that dictate player action from game state, power spike alerts, enemy cooldown or ultimate timers. ^f4
  > Notifications that dictate player action based on the current game state (e.g. Enemy champion is underleveled, go gank top lane).
  > The use of _**Ultimate timers**_ is strictly forbidden since this may provide an unfair advantage.
- [policy] Riot bans display of TFT Legend and Augment win rates and Augment placements. ^f5
  > Do not display Augment Win rates
- [policy] Brawl and League Classic data must not be aggregated or shown by third-party apps. ^f6
  > Riot Games does **NOT** approve any Brawl related data being aggregated or visible on third-party products/apps.
- [policy] Checked, not there: no ban on champion pick recommendations, champion win rates or team win probability in champ select; the champ select rule is only name anonymity. ^f7

## Read

- Whole page (TFT, Valorant, LoL sections)

## Not read

- Riot in-game ads rules page; Overwolf general overlay compliance page
