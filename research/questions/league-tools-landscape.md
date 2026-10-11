---
status: decided
decision: docs/concept.md
priority: soon
tags: [tools, market, learning, fun]
description: What League of Legends third-party tools exist, what do they do with match data, and where are the gaps?
---
# What League of Legends third-party tools exist, what do they do with match data, and where are the gaps?

Feeds: docs/concept.md (which product meiolol becomes; avoid crowded categories)

## Answer

Champion and matchup stats are crowded: six large ad-and-subscription sites (op.gg,
mobalytics, u.gg, leagueofgraphs, lolalytics, blitz) plus big companion apps (C1, C5, C6). A
newcomer cannot win there on traffic (C7). They already crawl timelines but reduce them to
single snapshots per matchup: GD@15, lane kill rate, first tower, kill lead at 10/20 (C2).
None shows how a specific lane develops minute by minute, or why and when it is won (C3);
matchup teaching that exists is thin and human-made (C4).

Novel formats: champion trivia dailies (LoLdle) reach millions of visits on ads without
match data, and the -dle niche is saturated (C10, C11). A draft guess-the-winner game
(AramGuessr, now LeagueGuessr) launched well, got a production key and RSO quickly, and
lives on with weak monetisation (C9). No daily, same-for-everyone draft puzzle or matchup
quiz exists (C12); MOBA Trainer's daily strategy puzzles are the closest learning
analogue, engagement unproven (C13). Replay-file tools are a dead end after 26.20 (C14).
Friend/Discord trackers are crowded and small (C15). Tools die mostly of traffic loss and
neglect (C16, weak).

## Claims

- C1: Champion and matchup stats are crowded: at least six large sites offer builds, tiers, counters and matchup win rates at millions of games. for: [[similarweb-opgg-competitors#^f2]], [[ugg-faq#^f1]], [[ugg-faq#^f4]], [[lolalytics-darius-vs-garen#^f2]], [[leagueofgraphs-darius-stats#^f5]]
- C2: Timeline-derived stats are mainstream but only as single snapshots (GD@15, lane kill rate, first tower, kill lead at 10/20, early items). for: [[ugg-darius-counter#^f1]], [[opgg-darius-counters#^f1]], [[leagueofgraphs-darius-stats#^f2]], [[lolalytics-darius-vs-garen#^f4]], [[overwolf-porofessor#^f3]]
- C3: No major tool shows a per-matchup curve over time or explains when and why a lane is won (absence checks, one page each). for: [[ugg-darius-counter#^f5]], [[opgg-darius-counters#^f7]], [[lolalytics-darius-vs-garen#^f7]], [[leagueofgraphs-darius-stats#^f8]], [[overwolf-porofessor#^f7]], [[mobalytics-vs-opgg#^f8]]
- C4: Existing matchup teaching is thin and human-made (crowd tips often empty, expert content, paid coaching). for: [[opgg-darius-counters#^f3]], [[opgg-darius-counters#^f4]], [[mobalytics-vs-opgg#^f4]], [[mobalytics-app-download#^f2]]
- C5: Incumbents monetise ad-funded scale plus subscriptions; ownership is concentrated. for: [[ugg-faq#^f6]], [[ugg-faq#^f7]], [[google-blitz-story#^f2]], [[porofessor-faq#^f5]], [[porofessor-faq#^f6]]
- C6: Companion apps are big: Porofessor 17.7M Overwolf downloads, iTero 1M+, Blitz 3M daily (self-reported). for: [[overwolf-porofessor#^f1]], [[itero-home#^f4]], [[google-blitz-story#^f1]]
- C7 (inferred): A newcomer should build a feature incumbents lack, not compete on generic stats. from: C1, C3, C5
- C8: "Wins lane" and "wins game" disagree per matchup (Kayle tops win rate vs Darius, Heimerdinger tops GD@15). for: [[ugg-darius-counter#^f4]]
- C9: Draft guess-the-winner games have traction (Reddit, press, 3 years alive) and got a key fast, but monetise weakly. for: [[reddit-aramguessr-update#^f2]], [[reddit-aramguessr-update#^f4]], [[reddit-aramguessr-update#^f6]], [[pcgamesn-leagueguessr#^f1]], [[leagueguessr-site#^f1]]
- C10: Daily champion-trivia games reach ~2M visits a month on ads alone, without match data. for: [[similarweb-loldle#^f1]], [[similarweb-loldle#^f4]], [[loldle-site#^f3]], [[loldle-site#^f5]]
- C11: The champion-trivia -dle niche is saturated with clones. for: [[similarweb-loldle#^f6]], [[loldle-site#^f4]]
- C12: No daily draft puzzle or matchup quiz found; nearest are an endless draft guesser and a daily strategy trainer (3 targeted searches found nothing). for: [[leagueguessr-site#^f2]], [[overwolf-mobatrainer#^f7]], [[awesome-league#^f8]]
- C13: Daily streak-based League learning puzzles exist and get downloads, engagement unproven. for: [[overwolf-mobatrainer#^f1]], [[overwolf-mobatrainer#^f3]], [[overwolf-mobatrainer#^f4]]
- C14: Replay-file analysis is a dead end for a Riot-friendly tool after 26.20/26.21. for: [[rofl-replay-parser#^f1]], [[lol-patch-26-20#^f2]], [[replaybook#^f4]]
- C15: Friend and Discord group trackers are a crowded small niche. for: [[topgg-dorans-bot#^f5]], [[topgg-dorans-bot#^f6]], [[awesome-league#^f4]]
- C16: Tools die from traffic loss and neglect more than key revocation. for: [[esportsnet-lolking#^f1]], [[esportsnet-lolking#^f4]]

## Disagreements

Traffic figures are Similarweb estimates; an unverified Semrush snippet (op.gg ~65M, u.gg
~39M, mobalytics ~27M visits) could not be snapshotted.

## Open

- Incumbents could add per-matchup curves cheaply (they have the data): the moat is
  explanation and the learning loop, not the numbers.
- Not read: U.GG PLUS/Blitz Pro/Mobalytics Plus pricing, Mobalytics GPI method, champdle/
  buildle modes, YearIn.LoL traction, riftcoach-agent.
