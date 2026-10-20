---
title: Porofessor.gg featured live games, streamer-mode players (2026-10-20)
url: https://porofessor.gg/?region=euw
kind: docs
commit:
for: [streamer-mode-names]
looked: 2026-10-20
depth: docs (Featured Games list on the homepage; live game page 403)
relevance: high
grade: B/fair
description: Second snapshot of the Porofessor homepage, read for how its featured live games show streamer-mode players; cross-checked against our own spectator-v5 call
---
# Porofessor.gg featured live games: streamer-mode players (2026-10-20)

Why: how the biggest live scouting site shows players who have Hide My Name on.
Earlier snapshot of the same page for another question: [[porofessor-home]].

## Assessment

- Evidence: B. The live page through real Chrome, 8 featured games (80 seats), checked
  against Riot's spectator-v5 for one of them (our own Riot API call on 20 Oct, not snapshotted).
- Reasoning: fair. What it shows, no explanation.
- Interests: vendor.
- Weigh: the live game page itself (porofessor.gg/live/...) is behind a Cloudflare
  challenge (403 to fetch and browse), so only the homepage list was read. Fetched
  from https://porofessor.gg/; the url's ?region=euw only keeps it apart from
  [[porofessor-home]].

## Findings

- [ux/features] [privacy] Featured Games lists live Ranked Solo/Duo games, each seat
  as Riot ID plus rank; a streamer-mode seat shows the text "Streamer Mode" with no
  rank, in place of the name. 10 of 80 seats were Streamer Mode. ^f1
  > Ranked Solo/Duo (10:14) EUW
- [privacy] In the EUW game 8019181098, Porofessor's four "Streamer Mode" seats are
  exactly the four seats spectator-v5 returns with a champion name and a null puuid;
  the other six show Riot ID and rank (e.g. Challenger). ^f2
  > YELLOWSUPERCAR87#1481
- [privacy] A seat is never dropped: the hidden player keeps its place in the team
  list, only name and rank are replaced. ^f3
- [ux/features] Each featured game links to the live page of a visible player, never
  a hidden one. ^f4
- [privacy] Checked, not there: no explanation or help link next to "Streamer Mode". ^f5

## Read

- Featured Games list on the homepage

## Not read

- porofessor.gg/live/euw/BUILT-2603 and /current-games (Cloudflare challenge, 403)
