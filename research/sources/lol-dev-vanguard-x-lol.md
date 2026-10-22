---
title: "/dev: Vanguard x LoL (Riot mirageofpenguins, 2024-04-11)"
url: https://www.leagueoflegends.com/en-us/news/dev/dev-vanguard-x-lol/
kind: docs
commit:
for: [league-apps-feature-matrix]
looked: 2026-10-22
depth: skimmed (third-party, scripting and AI sections read in full)
relevance: medium
grade: A/strong
description: Riot anti-cheat lead's player-facing dev blog on bringing Vanguard to LoL: scripting scale, why kernel mode, and that memory-reading tools will be broken on purpose
---
# /dev: Vanguard x LoL (Riot mirageofpenguins, 2024-04-11)

Why: Riot's own account of what Vanguard (2024) means for third-party tools.

## Assessment

- Evidence: A. Official LoL dev blog by Riot's anti-cheat lead, 11 Apr 2024, with
  internal numbers.
- Reasoning: strong. Explains costs, alternatives (AI anti-cheat, allow lists), limits.
- Interests: Riot (justifying a kernel driver).
- Weigh: the third-party stance is plain and matches the DevRel FAQ.

## Findings

- [tools/removed] [policy] Tools not on official APIs will find it hard to keep reading
  client memory, as that is what cheats do. ^f1
  > Developers [not using the official APIs](https://www.riotgames.com/en/DevRel/vanguard-faq) will find it difficult to continue exfiltrating information directly from client memory, primarily because that's exactly what cheats do.
- [policy] No allow list, because Riot would then own those tools' security. ^f2
  > One of the key concerns with allow-listing specific tools is that we are then responsible for their security when cheats seek to leverage them
- [tools/removed] [policy] Riot promises to break memory-reading tools deliberately. ^f3
  > If tools choose to read client memory anyway, we make no guarantees that it won't break. In fact, we promise to deliberately break it as often as possible.
- [policy] [data] Scale of the problem: up to 1 in 15 games globally had a scripter or
  botter. ^f4
  > as many as **1 in 15 games globally has had a scripter or botter in it**
- [policy] Information cheats (ESP, fog of war leaks, radar) are hard to detect from server
  data, which is why information-revealing tools worry Riot. ^f5
  > ESPs, FoW leaks, and radar hacks are almost totally undetectable
- [policy] (inferred) Riot's line for tools is the data route (official APIs yes, memory
  no) plus the information rule; the 2026 memory block
  ([[riot-memory-access-removed#^f1]]) finishes what this post started. An LCU and
  Riot API tool is on the safe side of both. ^f6

## Read

- intro, scripting numbers, "Does Vanguard break 3rd party tools?", "Why not AI
  Anti-Cheat?"

## Not read

- Linux, Mac and driver sections in detail
