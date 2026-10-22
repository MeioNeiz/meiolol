---
title: How to Use the Mobalytics Overlay + Live Companion (Nov 2020 guide)
url: https://mobalytics.gg/blog/lol-how-to-use-mobalytics-live-companion/
kind: docs
commit: 
for: [league-apps-feature-matrix]
looked: 2026-10-22
depth: docs (overlay section and Live Companion section to team analysis)
relevance: high
grade: B/fair
description: Mobalytics' Nov 2020 guide to its overlay and Live Companion: before-queue tier list, own champions and GPI focus; champ select player scouting with playstyle badges, opponent's record vs your champion; overlay with enemy level 6 and item pop-ups, standings, matchup info
---
# How to Use the Mobalytics Overlay + Live Companion (Nov 2020 guide)

Why: the fullest first-party list of what a big companion app showed in each phase
before Riot's 2022 to 2025 restrictions; a baseline for what was later removed.

## Assessment

- Evidence: B. Vendor guide by Agilio Macabasco, November 25, 2020 (Live Companion
  launched April 2020); still live Oct 2026 (redirects to
  /lol-how-to-use-mobalytics-overlay-live-companion/).
- Reasoning: fair. Explains each widget and how to use it.
- Interests: vendor.
- Weigh: historical. Its "approved by Riot" line predates the rule against claiming
  approval ([[overwolf-riot-compliance#^f2]]).

## Findings

- [tools/phase] Lobby (before queue): the last ten games, tier list highlights for your
  role, your champions' stats, a new-champion suggestion from the free rotation, and your
  GPI skill to focus. ^f1
  > As you get ready to jump into queuing, the Live Companion will provide you with a quick look at your ten most recent games and provide recommendations based on your identity as a player.
- [tools/phase] [needs] The new-champion suggestion is pitched for normals and flex, to
  protect solo queue LP. ^f2
  > This feature is more suited for playing Normal or Flex matches since it’s more about experimenting (you gotta protect that solo queue LP!).
- [tools/phase] Champ select (2020): player scouting of all players: rank, games and win
  rate on role and champion, spells, runes, playstyle badges; deep profile and side by
  side player comparison. ^f3
  > As soon as you hit Play and enter your match’s Champ Select, your Live Companion will transform right before your eyes
  > Number of games played + win rate for their champion
- [tools/phase] Champ select (2020): Opponent Insight, the lane opponent's recent record
  against your champion. ^f4
  > Opponent Insight, which indicates a player’s recent performance stats against your specific champion.
- [tools/phase] Champ select: build import with auto-import option, skill order, level 1
  starter kit, champion combos, matchup stats and advice for both sides, power spikes by
  stage, team power spikes and averages. ^f5
  > If you want to save even more time you can set your Live Companion to Auto-Import in your Settings.
  > the Live Companion provides advice for both sides of a matchup
- [tools/phase] In game (2020): overlay on Tab with player stats and badges, game
  overview with standings and head to head, matchup info with cooldowns and power spikes. ^f6
  > While holding Tab, you can press Q, W, E, or S to access the different parts of the Overlay.
- [tools/removed] In game (2020): pop-ups when enemies hit level 6 and unlock their
  ultimate, or finish a major item; claimed approved by Riot at the time. ^f7
  > For example, when your enemies hit level 6 and unlock their ultimate, you’ll receive a handy pop-up!
  > And if you’re wondering, yes, it is approved by Riot!
- [policy] (inferred) Enemy level 6 pop-ups are power spike alerts, a category Riot's
  rules (via Overwolf) now prohibit ([[overwolf-riot-compliance#^f4]]); the 2026 listing
  still names "powerspike notifications" ([[overwolf-mobalytics-desktop#^f9]]). ^f8
- [tools/accounts] The overlay needs your summoner name set in the desktop app's
  settings. ^f9
  > If you have the right summoner name set in your Desktop App’s Settings, your Overlay will be ready to go as soon as you’re in-game.
- [tools/accounts] [ux/features] Team power spikes and averages pitched for organised
  play and Clash, to share with teammates. ^f10
  > This widget is especially useful in organized competitive play and Clash so be sure to give your teammates the scoop to help you play optimally.

## Read

- Overlay guide; Live Companion guide up to team analysis

## Not read

- Damage type, gank and post-game sections of this guide (covered by
  [[mobalytics-desktop-guide]])
