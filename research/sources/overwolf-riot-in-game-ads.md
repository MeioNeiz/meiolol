---
title: "Overwolf: Riot in-game ads rules (developer docs, 2026)"
url: https://dev.overwolf.com/ow-native/guides/game-compliance/riot-in-game-ads
kind: docs
commit:
for: [league-apps-feature-matrix]
looked: 2026-10-22
depth: docs (whole page)
relevance: high
grade: B/fair
description: Overwolf's six rules for ads in overlays on Riot games (opt-in, dimming, no floating ads, no in-game upsell, visually distinct from Riot UI), current version
---
# Overwolf: Riot in-game ads rules (developer docs, 2026)

Why: how the May 2025 third-party ad ban ([[overwolf-riot-creators-response#^f1]]) is
applied today, and the UI rules every overlay must follow.

## Assessment

- Evidence: B. Overwolf's live developer docs; undated, but reflects the post-ban
  settlement (ads allowed again inside overlays the player opens).
- Reasoning: fair. Each rule with a reason and a compliant and non-compliant example.
- Interests: Overwolf (ad platform).
- Weigh: Overwolf's reading of Riot's rule, not Riot's text. It is softer than the May
  2025 tweet (which banned overlay ads outright), so Riot and Overwolf likely agreed a
  middle way; unconfirmed from Riot.

## Findings

- [tools/paid] [policy] In game: ad-bearing overlays must be opt-in, opened only by a
  player action, never automatically. ^f1
  > You can auto-launch your app, but any in-game windows containing ads must not appear automatically and should only open in response to a user action, such as a hotkey press or mouse click.
- [tools/paid] [policy] No floating ads; ads only inside an overlay with real content
  the player opened. ^f2
  > If you're going to show ads, they must appear inside an overlay the player intentionally opened and not float over gameplay like a banner.
- [tools/paid] [policy] No upsell in game: subscription and ad-removal prompts only
  outside the game session (home screen, pre or post game). ^f3
  > You must not show subscription offers or upgrade CTAs inside any in-game overlay, even if the user opted into that overlay.
  > All subscription call to action messaging must happen outside of the game's context (e.g., in the app's home screen or pre/post-game flow).
- [ux/features] [policy] Overlays must not cover minimap, scoreboard, shop, ability bar
  or menus. ^f4
  > Overlays must be placed so they don't cover important UI elements, such as minimaps, scoreboards, shops, ability bars, or system menus.
- [ux/features] [policy] Overlays must look unlike Riot's UI: own fonts, colours, buttons,
  clear app branding. ^f5
  > Your overlay should never look like it's part of the official Riot game UI. Players must always be able to tell when they're interacting with a third-party tool, not the game itself.
- [ux/features] Large ad overlays over gameplay must dim the game and offer a clear way
  back. ^f6
  > Any large overlay, or window with an ad shown over gameplay must include a dimmed background to visually separate it from the game.
- [tools/paid] (inferred) Paid tiers sell "no ads", but the upgrade prompt cannot appear
  in game, so the sales moment is the desktop app home and post-game screens. ^f7

## Read

- whole page

## Not read

- Overwolf general overlay compliance overview page; the Figma best-practice file
