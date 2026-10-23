---
title: OP.GG for Desktop on the Overwolf app store
url: https://www.overwolf.com/app/opgg-electron-app
kind: docs
commit: 
for: [league-apps-feature-matrix, desktop-app-layout]
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

- [ux/desktop] Champ select (2026): a three-column board, "My team" left (five rows:
  champion icon, name, role; your row marked ME; empty rows "Choosing ADC"), "Enemy
  team" right mirrored, bans as small icons at the foot of each column; the middle has
  tabs Lane tiers, Counters, Team. The Counters view for your role ("Counter picks MID
  vs Annie") is two lists side by side, "Good picks" headed in blue and "Bad picks" in
  red, each row icon, name, WR and Kills %, eight rows; "Recommended MID" and "Win rate
  by length" panels sit below (seen in screenshot overwolf-opgg-champselect.webp). ^f9
- [ux/desktop] Window chrome: a far-left rail of game icons (LoL, TFT, Valorant...), a
  top tab bar My profile, Live (New), Champions, Overlays, AI Agent, spell-key setting
  (D / F) top right; dark grey, purple accent (seen in screenshot overwolf-opgg-champselect.webp). ^f10
- [ux/desktop] Older 2023 layout (v19): a left nav column (Live Game: Multi-Search,
  Champion, In-Game; Champions: Tiers, Combo Videos, OP Champions; TFT), with the
  live lobby as five tall player columns side by side: rank chip, champion portrait
  with level, name, ladder rank and LP, win / loss bar and %, two role icons with
  share and win rate, then "Recently Played" (ten KDA rows, red loss / blue win, time
  ago) and "Most Played Champions" (KDA ratio coloured, win % red / blue, games). The
  own column is outlined in purple (seen in screenshot overwolf-opgg-multisearch.jpg). ^f11
- [ux/desktop] Build page in the same shell: role tabs, region, tier and patch dropdowns
  on top; rune page cards as radio columns with W/R and games; item builds as rows with
  W/R, P/R and games; "Weak Against" and "Strong Against" as horizontal icon strips
  with W/R in red or blue (seen in screenshot overwolf-opgg-build.jpg). ^f12
- [ux/desktop] In game: two small rounded panels at screen edges with a hotkey line
  (Alt + Caps Lock): Item Build (recommended path with WR and PR chips, two other
  builds) on the left, Live Stats (gold over time vs average line chart, CS/min and
  Gold/min with green deltas) on the right; timers on the minimap (seen in screenshot
  overwolf-opgg-ingame.webp). ^f13

## Read

- Whole listing

## Not read

- Reviews (none shown on the listing); OP.GG help centre on the desktop app
