---
title: Facecheck on the Overwolf app store (v1.9.52, Sep 2026)
url: https://www.overwolf.com/app/convex_apps-facecheck
kind: project
commit: 
for: [league-apps-feature-matrix]
looked: 2026-10-22
depth: docs (store listing, whole page)
relevance: high
grade: C/fair
description: Facecheck (Convex Apps) Overwolf listing: all-phase League and TFT companion, pick and ban suggestions, lobby tags, in-game widgets and opponent habits, post-game breakdown; free with ads plus subscription; 3.16M downloads
---
# Facecheck on the Overwolf app store (v1.9.52, Sep 2026)

Why: what Facecheck offers per phase and whether it charges; it is one of the bigger Overwolf League apps not covered by other readers.

## Assessment

- Evidence: C. Store listing: 3.16M downloads, 4.6 from 440 ratings, v1.9.52 dated 24 Sep 2026; Overwolf native client app, 3.9 MB.
- Reasoning: weak. Feature list.
- Interests: vendor copy.
- Weigh: the phase-by-phase feature list is the useful part; reviews are short and one is an XSS probe, so the rating says little.

## Findings

- [tools/paid] Free with ads, subscription available (no price or tier list on the listing). ^f1
  > Subscription available
- [tools/phase] [ux/features] Champ select: pick and ban recommendations from team composition, enemy counters and meta; lobby scouting by "Tags"; one-click import of builds and runes. ^f2
  > Receive intelligent pick and ban recommendations based on your team composition, enemy counters, and the current meta.
  > Identify champion and team patterns based on customized and smart Tags
  > Import the most effective, high-level builds and runes directly into your client
- [tools/phase] [ux/features] In game: overlays for enemy summoner spells, jungle camp respawns and player stats; "Summoner's Insights" on enemy habits; champion strength and weakness tags; jungle pathing routes. ^f3
  > clean, simple overlays for enemy summoner spells, jungle camp respawns, and key player stats
  > Get a sneak peek into enemy habits with Summoner's Insights
- [tools/phase] [ux/features] In game: second monitor view of real-time damage dealt and taken; automatic highlight recording. ^f4
  > Use a second monitor for a rich, expanded view of in-game stats, including real-time damage dealt, damage taken, and other critical data.
  > automatically records your best moments
- [tools/phase] [ux/features] Post game: breakdown of who dominated or underperformed with key stats compared; long-term stat tracking across champions. ^f5
  > See who dominated, who underperformed, and compare key stats to understand exactly what decided the match.
- [fun] Engagement hook: weekly RP giveaways for users. ^f6
  > Enter our weekly giveaways for a chance to win RP prizes, just for being a Facecheck user.
- [policy] (inferred) Enemy summoner spell tracking in game is the kind of overlay Riot restricted in 2025 (ult and spell timers); the listing still names it as of Sep 2026, so either it is limited to what Riot allows or the copy is older than the rule. Verify. ^f7
- [market] 3.16M downloads, 4.6 from 440 ratings (short page lines, unquotable). ^f8
- [tools/accounts] Checked, not there: no sign-in, Riot Sign On or friends feature named. ^f9

## Read

- Whole listing, six visible reviews

## Not read

- Facecheck's own site and subscription page (facecheck.gg or similar, not found yet)
