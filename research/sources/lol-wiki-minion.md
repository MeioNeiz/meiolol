---
title: 'League of Legends Wiki: Minion'
url: https://wiki.leagueoflegends.com/en-us/Minion_(League_of_Legends)
kind: docs
commit:
for: [kill-vs-farm-value]
looked: 2026-10-20
depth: docs (waves, mechanics, wave gold value, patch history V26.01 back to V12)
relevance: high
grade: B/fair
description: Community wiki page on lane minions: wave timing and composition, XP sharing, wave gold by game time, patch history
---
# League of Legends Wiki: Minion

Why: does minion wave gold and XP stay flat over the game, and do cannon waves lose a
melee minion after 14 minutes, as Coach Rogue's Moneyball video says?

## Assessment

- Evidence: B. Official community wiki on Riot's wiki domain; numbers per patch with
  history back to beta, cross-checked against Riot's 26.1 notes ([[lol-patch-26-1]]).
- Reasoning: fair. States rules and shows the wave gold arithmetic; no derivation of XP.
- Interests: none.
- Weigh: trust rules that match patch notes; the "undocumented" items (siege threshold
  14:00) are editors' measurements from VODs, linked.

## Findings

- [learning] [data] Waves spawn every 30 s from 0:30, every 25 s from 14:00 and every
  20 s from 30:00, so a lane's minion income per minute rises even when each wave's
  value does not. ^f1
  > Starting from **00:30**, _waves_ spawn every 30 seconds.
  > At **14:00**, _waves_ spawn every 25 seconds (with sequence of 13:30 / 14:00 / 14:25).
  > At **30:00**, _waves_ spawn every 20 seconds (with sequence of 29:25 / 29:50 / 30:10).
- [learning] [data] Confirms the video: after 14:00 a cannon wave has one fewer melee
  minion; after 30:00 every wave loses a caster. ^f2
  > After **14:00**, when a siege minion spawns on these waves, one fewer melee minion spawns.
  > After **30:00**, one fewer caster minion spawns per wave.
- [learning] [data] Cannon frequency rises: from wave 3 (1:30) one every 3 waves, every
  2 waves after 14:00, every wave after 25:00. ^f3
  > The first one spawns with the third wave (at 01:30).
  > Then, for the first 14 minutes, one spawns every three waves.
  > After the 25 minute mark, one spawns every wave (with sequence of 24:25 / 25:15 / 25:40).
- [data] Average gold per wave since V26.01 runs 115 to 148 by game time: 118.66 at
  0:30, 115 at 14:00, 121.5 at 15:00, 148 at 25:00, 137 at 30:00 (melee 20, caster
  14, siege 50 rising to 69). Per CS it rises from 18.7 to 27.4. ^f4
  > a **minion wave** has an _average_ gold value that varies from 115 and up to 148, depending on game time.
- [learning] Minion XP is split equally among the killer and all nearby enemy
  champions within 1500 units. ^f5
  > bounty is split equally among the killer and all nearby enemy champions within 1500 units of its death location.
- [data] V26.01 (season 2026 start) brought the 25 s and 20 s wave timers, minions at
  0:30, first cannon on wave 3, and XP share 100/65/43.3/32.5/26/21.7%. ^f6
  > Minion experience share changed to 100 / 65 / 43.3 / 32.5 / 26 / 21.7% from 95 / 62 / 41.3 / 31 / 24.8 / 20.7%.
- [learning] Minion level follows the team's average champion level (rounded down), and
  minions upgrade every 90 s; this changes their stats, not their XP. ^f7
  > New spawning minions level up based on their team's average champion level, rounded down to integer
- [learning] (inferred) Per lane, from these rules: about 240 gold and 608 XP a minute
  before 14:00, 295 / 685 at 14-25, 360 / 701 at 25-30, 423 / 783 after 30 (sums of
  wave values times waves a minute). Per wave the value is roughly flat, as the video
  says, but per minute lane gold rises about 75% and XP about 30% over a game. ^f8

## Read

- Minion waves, mechanics, Wave Gold Value, patch history V26.01 to V12.22

## Not read

- Buffs and pushing sections (stats only, no rewards)
