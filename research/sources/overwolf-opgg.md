---
title: OP.GG for Desktop on the Overwolf app store
url: https://www.overwolf.com/app/opgg-electron-app
kind: docs
commit: 
for: [league-apps-feature-matrix]
looked: 2026-10-22
depth: docs (whole listing)
relevance: high
grade: B/fair
description: OP.GG for Desktop listing, Oct 2026: standalone Overwolf Electron app, 84.7M downloads; phase-aware ban/pick assistant, auto runes, in-game overlay, AI Agent voice coach (beta)
---
# OP.GG for Desktop on the Overwolf app store

Why: the current, phase-by-phase feature list of the biggest stats site's desktop app,
which op.gg/desktop ([[opgg-desktop]]) gives only as overlay names.

## Assessment

- Evidence: B. Platform store listing; download count is Overwolf's; listing text is
  OP.GG's own and newer than the app info line (1.2.2, Nov 2023), since it names ARAM:
  Mayhem and the AI Agent.
- Reasoning: fair. Concrete feature list, one line per phase.
- Interests: vendor and platform.
- Weigh: trust the feature list as what OP.GG ships; downloads are cumulative and
  multi-game (LoL, TFT, Valorant).

## Findings

- [market] 84.7M downloads; free with ads, no subscription flag on the listing; a
  standalone Electron app, no Overwolf client needed. ^f1
  > Note: This is a standalone app. It does not require installing the Overwolf client.
  > Downloads 84.7M
- [tools/phase] [draft] Champ select: a Ban/Pick Assistant that changes with the draft:
  lane tier list in bans, safe blind picks, counter picks once the lane opponent locks,
  team comp analysis after picks. ^f2
  > switches automatically as the draft goes on. Lane tier list during bans, safe blind picks, counter picks once your lane opponent is locked in, and team comp analysis after picks
- [tools/phase] Champ select: runes, spells and items applied to the client on lock-in. ^f3
  > lock in your champion and your setup is applied to the client
- [tools/phase] In game: jungle and inhibitor timers, live stats against the lane
  opponent and tier average, item builds, skill order, ARAM: Mayhem augment tiers. ^f4
  > jungle and inhibitor timers, real-time stats vs. your lane and tier average, item builds, skill order, ARAM: Mayhem augment tiers
- [tools/phase] In game: AI Agent (beta), a push-to-talk voice coach with laning tips,
  real-time danger alerts, fight reviews and build coaching. ^f5
  > a voice game coach with laning tips, real-time danger alerts, fight reviews and build coaching. Just push to talk
- [ux/features] Overlay toggles with Shift+Tab, each widget on or off; 24 languages;
  second monitor support. ^f6
  > Toggle the overlay with Shift+Tab and turn each widget on or off
- [tools/phase] Checked, not there: no loading screen scouting, lobby or post-game
  feature for LoL in the listing (post-game review only for Valorant aim); no mention of
  login, friends or groups. ^f7
- [policy] (inferred) "Real-time danger alerts" from the AI Agent sit close to Riot's ban
  on notifications that dictate action from game state ([[overwolf-riot-compliance#^f4]]);
  what it really alerts on is unverified. ^f8

## Read

- Whole listing

## Not read

- Reviews (none shown on the listing); OP.GG help centre on the desktop app
