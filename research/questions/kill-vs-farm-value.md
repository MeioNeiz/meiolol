---
status: answered
priority: later
area: product
tags: [learning, data]
description: Is farm value flat while kill value and kill rate rise with game time, so ganking and grouping beat farming from about level 8 or 20 minutes, as Coach Rogue's Moneyball video claims?
---
# Is farm value flat while kill value and kill rate rise with game time, so ganking and grouping beat farming from about level 8 or 20 minutes, as Coach Rogue's Moneyball video claims?

Feeds: Learn content (docs/learn-proposal.md) and game-phase framing on the site; a
check of a popular coach's claims before we repeat or contradict them.

## Answer

Half right. The XP side holds: a solo kill's XP climbs steeply with the victim's level
and passes a cannon wave at about level 7 to 8 (C3), while camp XP stops growing at
camp level 8 (C6). The kill rate also rises, from 1.2 a minute in the first five
minutes to 2.7 by 20-25 (C8). The gold side does not: base kill gold is 300 to 420,
already about twice a cannon wave at level 2, and in our games gold per kill only goes
from about 300 to 390 over a game (C4, C9). And farm is flat per wave but not per
minute: waves come faster at 14 and 30 minutes, so lane gold a minute rises about 75%
(C1). The video's late-game dip in kill rate is not in our data, where the rate holds
at 2.8 a minute from 25 minutes on (C10).

So the honest version: early fighting costs XP more than gold; kills get more frequent
and worth more XP as levels rise, which favours ganking and grouping in the mid game,
but the swing is smaller than the video draws, and for assisted kills the XP
crossover is level 11 to 12, not 7 (C5). Its split push then group advice is
reasonable but not shown by these numbers, since it ignores gank success odds and
what is lost while roaming (C11).

## Claims

- C1: Per wave, minion gold and XP are near flat (115 to 152 gold), but waves come every 30 s, then 25 s from 14:00 and 20 s from 30:00, so a lane's gold a minute rises about 75% and XP about 30% over a game. for: [[lol-wiki-minion#^f1]], [[lol-wiki-minion#^f4]], [[lol-patch-26-1#^f1]] against: [[coachrogue-moneyball-stats#^f1]]
- C2: Cannon minion gold rises only 1 per 90 s since 26.1, and cannon waves lose a melee minion from 14:00. for: [[lol-wiki-siege-minion#^f1]], [[lol-patch-26-1#^f4]], [[coachrogue-moneyball-stats#^f1]]
- C3: Solo kill XP rises steeply with victim level (114 at 2, 392 at 8, 690 at 12) and passes a cannon wave at level 8, level 7 after 14:00. for: [[lol-wiki-experience-src#^f1]], [[lol-wiki-experience#^f1]], [[coachrogue-moneyball-stats#^f2]]
- C4: Base kill gold barely scales with level (300 at 1-6, then +10 a level to 420); real kill gold follows bounties and shutdowns far more, so in gold a kill beats a cannon wave at every level. for: [[lol-wiki-champion-gold-bounties#^f1]], [[lol-wiki-champion-gold-bounties#^f4]] against: [[coachrogue-moneyball-stats#^f4]]
- C5 (inferred): The XP crossover holds only for solo kills on equal-level victims: with an assist it moves to about level 11 to 12, and level gaps shift it further. from: C3, [[lol-wiki-experience-src#^f5]], [[lol-wiki-experience#^f3]]
- C6: Jungle camp XP scales with the game's average level up to camp level 8, then is flat; camp gold is flat. for: [[lol-wiki-gromp-src#^f1]], [[lol-wiki-monster#^f1]], [[lol-wiki-gustwalker#^f1]], [[coachrogue-moneyball-stats#^f3]]
- C7: Death timers rise with level (10 s to 52.5 s) and from 15 minutes with game time, up to +50%. for: [[lol-wiki-death#^f1]], [[lol-wiki-death#^f2]]
- C8: Ranked solo has about 64 kills a game, 2.2 a minute; the rate rises from 1.16 a minute at 0-5 min to 2.33 at 10-15 and 2.68 at 20-25. for: [[kill-rate-by-minute-measured#^f1]], [[kill-rate-by-minute-measured#^f2]], [[coachrogue-moneyball-stats#^f5]]
- C9: Gold per kill in real games (bounty plus shutdown) rises only about 30%, from 295 at 5-10 min to about 385 after 35. for: [[kill-rate-by-minute-measured#^f4]]
- C10: The kill rate does not fall late: per minute of games still running it holds at 2.8 from 25 minutes to 45+. for: [[kill-rate-by-minute-measured#^f3]] against: [[coachrogue-moneyball-stats#^f6]]
- C11 (inferred): The video's advice (farm and split early, gank from level 8, group after 20 min) follows from the XP side only and leaves out the cost side: gank success odds, the wave and plates lost while roaming. from: C3, C5, C8, [[coachrogue-moneyball-stats#^f13]]

## Disagreements

- Kill rate late game: the video shows a dip at 25-30 minutes ([[coachrogue-moneyball-stats#^f6]], C grade, hand-counted, no sample size); our 290k games show none (C10, A). Most likely the video divides by all games rather than games still running; a quarter have ended by 25 minutes.
- Shared kill XP: the wiki's page text says it depends on the victim's level, its patch history line says the earner's level ([[lol-wiki-experience#^f8]]). Settle with a timeline check: XP jumps at assisted kills.

## Open

- The value of a kill against a wave by role and rank in our timelines: XP and gold gained at each kill, and lane CS lost by the roamer in the minute around a roam.
- Gank success rate by minute (kills near the jungler's lane visits) would give the missing cost side; the events.tsv `kills_near_*` columns are a start.
- Could the minute bands feed the site: a "kills a minute by game time" line next to the lane curves, per rank?
