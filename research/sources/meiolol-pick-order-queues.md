---
title: 'meiolol: pick order by queue in match-v5 and spectator-v5 (own check, 2026-10-24)'
url: https://euw1.api.riotgames.com/lol/spectator/v5/active-games/by-summoner/{puuid}
kind: dataset
commit: 
for: [lol-site-ui]
looked: 2026-10-24
depth: ran (match-v5 for queues 400, 440, 480; spectator-v5 on 3 live ranked games, then match-v5 for the same games)
relevance: high
grade: B/fair
description: Live API check that normal draft, flex and swiftplay carry no pick order in match-v5, and that spectator-v5 lists live participants in a non-role order that may be champ select order
---
# meiolol: pick order by queue in match-v5 and spectator-v5 (own check, 2026-10-24)

Why: Jacob asked whether any game mode gives the pick order from the API (Daily Draft wants the real last pick).

## Assessment

- Evidence: B. Direct API calls, but small: 3 to 8 matches per queue, 3 live games.
- Reasoning: fair. Field-level facts are certain; what the spectator order means is not.
- Interests: none.
- Weigh: the spectator order result is a lead, not an answer: it could be cell order or
  an arbitrary server order. Test before building on it (see f4).

## Findings

- [data] [queues] Normal draft (400), ranked flex (440) and swiftplay (480) match-v5
  records list participants in role order and bans in slot order, exactly like ranked
  solo, so none of them carries pick order. ^f1
  > match-v5 queues 400, 440 and 480 list participants TOP,JUNGLE,MIDDLE,BOTTOM,UTILITY per team, as 420 does
- [queues] Swiftplay (480) games were served by match-v5 on 24 Oct 2026, with no bans. ^f2
  > swiftplay 480 has no bans and was served on 24 Oct
- [data] Spectator-v5 lists a live ranked game's participants in an order that is not
  role order and differs per game; match-v5 later sorts the same players by role. ^f3
  > spectator-v5 participant order within a team was not role order in any of the 3 ranked games
- [data] (inferred) If that order is the champ select cell order, polling live games
  gives each team's pick order (less pick-order swaps) for ranked. Test: bans are per
  cell (pickTurn = slot, -1 where a player skipped), and players ban the same champion
  game after game, so for players seen in several games the ban at their spectator
  position should repeat far more often than the ban at a shifted position. ^f4
- [data] Spectator-v5 bans equal the match-v5 bans exactly, slot for slot. ^f5
  > spectator-v5 bannedChampions equal match-v5 bans exactly, pickTurn 1-10, including -1 at the same slots
- [data] Checked, not tested: Clash (700), whose tournament draft might order bans by
  turn; no recent Clash games among the players tried. ^f6
  > Not tested: Clash 700

## Read

- `raw/meiolol-pick-order-queues.txt`: all outputs (puuids removed).

## Not read

- The f4 test needs ~50 live games with repeat players: about 20 spectator calls per
  6 minutes for a few hours on the shared personal key; stopped after 3 games because
  the key was near its limit.
