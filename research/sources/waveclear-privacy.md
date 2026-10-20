---
title: WaveClear privacy policy (15 Jul 2025)
url: https://www.waveclear.gg/privacy-policy
kind: docs
commit:
for: [league-tools-landscape]
looked: 2026-10-20
depth: docs (sections 1-2, 4 sharing, 7 retention; skimmed the rest)
relevance: high
grade: B/fair
description: WaveClear's privacy policy: what game, input and face-video data the Overwolf app collects, from Riot's and Overwolf's APIs and an optional emotion-analysis SDK
---
# WaveClear privacy policy (15 Jul 2025)

Why: how WaveClear gets its data (Riot API, Overwolf events, input tracking) and what it does
with it.

## Assessment

- Evidence: B. The company's own legal text, a first-hand statement of what it collects; dated
  15 Jul 2025, so it may lag the October 2026 app.
- Reasoning: fair; broad "includes but is not limited to" lists, not a technical spec.
- Interests: the company, but a privacy policy states practices against its own interest.
- Weigh: trust what it says it collects; it does not say how "focus" is computed.

## Findings

- [policy] [tools] Game data comes from Riot's API and Overwolf's API, including in-game
  clicks, match history, game statistics and real-time performance metrics, analysed to
  determine focus. ^f1
  > We may receive further from Riot’s API and Overwolf’s API, such as in game click, User game name, gameplay data, user match history, game statistics
  > We will analyze this data in order to determine your focus
- [privacy] Needs an Overwolf account and a LoL account; Overwolf passes the Riot game name and
  tag, which the app ties to its user. ^f2
  > we receive from Overwolf your LOL game name and game tag and uniquely associate your App and your LoL account in our systems
- [privacy] [tools] An optional feature installs the TruSight SDK (Revealense) to analyse the
  player's face on camera for stress and emotional response to game events; processed on the
  device, video not stored, the analysis shared with Revealense. ^f3
  > the TruSight SDK install package) which will collect and process your face image while you use the app
  > stress, emotional response to game events, and mindset training tools
- [privacy] Mentions in-app purchases through Overwolf payments, beside ads. ^f4
  > When you decide to make a purchase on our App, the payments are in-app payments
- [privacy] [policy] May share gameplay stats with third-party leaderboard and stats sites "in a
  manner similar to how Riot Games publishes such data", and, by choice, the player's measured
  "mindset". ^f5
  > We may further, subject to your choice, share your “mindset” as captured by our App
- [privacy] Under-16s may not use it. ^f6
  > IF YOU ARE UNDER THE AGE OF 16 YOU MAY NOT USE THE APP AND WEBSITE.
- [policy] Checked, not there: no mention of reading keyboard or mouse input outside the game
  events Overwolf supplies, no named Riot product registration or key. ^f7
