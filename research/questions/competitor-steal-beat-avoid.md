---
status: answered
priority: now
area: product
tags: [tools, ux/postgame, ux/uncertainty, policy]
description: From rivals' apps and sites, what should meiolol steal, beat or avoid, ranked and mapped to app.md steps and site.md items?
---
# From rivals' apps and sites, what should meiolol steal, beat or avoid, ranked and mapped to app.md steps and site.md items?

Feeds: docs/plan/app.md Steps; docs/plan/site.md "Your games" and other items; coordinator's run plan

## Answer

Ranked by what it would do for players and for the production review, each mapped to
where it lands in docs/plan/app.md or site.md; (done), (partly) or (new) says how far our
plan already goes. Our product for Riot is game review (riot-appreciated-tools C11), so
review items lead.

1. Beat: review by what each moment moved in win chance, never one stat-blend grade;
   print the baseline with every number. Your games review (partly: moments carry win
   chance moved); APP11 "our draft call against the result" (new). C1, C2
2. Steal: chess.com's guided walk: a summary, then Next through your key moments, one
   line each, ending on one thing to try next game. Your games review (new); APP11
   tabs (new). C3, C4
3. Steal: praise as much as fault: best plays, a win's low survived. Your games records
   (partly: best minute, biggest fight); moment labels for good fights (new). C5
4. Beat: thin cells pulled toward what thin cells win (rare picks about 39%), games
   shown, no raw best or worst lists. Site-wide win rate sort (partly: pulled to an
   average, not to the rare-pick level); champion page counters; APP5 chips; APP10's
   few games pill. C6, C7
5. Beat: patch day on last month's numbers with a small per-patch offset, said on the
   page. Patch changes; champion page; Matchup Later B4 (new). C8
6. Beat: your lane against the matchup at this minute; rivals benchmark against a tier
   or a 15 minute snapshot. APP9 companion (partly); Your games lane gold at 14 (done);
   Matchup page curves (done). C9
7. Steal: progress between games and recaps. Your games "more history" (new); Private
   site "progress between games" (new). C10
8. Steal: pool and experience before counters. Lane card mastery (done); app Later
   "Expertise bonus richer"; Pool page. C11
9. Steal: shareable results and friend ladders. Daily Draft share (done, hidden in
   preview); Private site group leaderboard and Discord bot (new). C12
10. Beat: publish the method and held-out accuracy; nobody big does. Before the
    production review (new: a method page from docs/model.md). C13
11. Steal: fewer numbers before the game, tags first, lane opponent first. APP10 pills
    (done); APP3 board (done). C14
12. Beat: rank as at the game, never looked up after it. Rank filters, Daily Draft's
    board ranks (check). C15

Avoid, ranked by risk:
A1. In-game prompts, spike alerts, enemy cooldowns, AI voice calls: APP9 stays a panel
    the player reads; app.md Policy line (done). C16
A2. Automation of selection and scouting in ranked champ select: app.md Policy line
    and APP7 (done). C17
A3. Per-option rune and build win rates as advice: champion page builds by popularity,
    a rate only with its games (partly); APP11 no rune verdicts. C18
A4. Metered LLM coaching as the product, uplift claims ("win 27% more") and bulk replay
    crawling: Your games stays timeline facts, free; site copy. C19
A5. Forced login, Overwolf and ads: app install and accounts (done). C20

## Claims

- C1: League per-game scores are stat blends players judge by their worst miss;
  Leetify's League score dropped the win-probability credit that made its CS2 one
  trusted. for: [[mobalytics-letter-to-users#^f2]], [[reddit-opgg-new-op-score#^f1]], [[leetify-rating-2024#^f4]], [[leetify-lol-rating#^f2]]
- C2: An unstated baseline confuses; one wrong tip discredits a whole system.
  for: [[mobalytics-gpi-explained#^f2]], [[reddit-mobalytics-valuable#^f1]], [[reddit-mobalytics-valuable#^f3]]
- C3: chess.com reviews as a walk: summary, then key moves one at a time with one
  sentence, Next and Retry. for: [[chesscom-game-review-help#^f1]], [[chesscom-game-review-app#^f4]], [[gothamchess-truth-game-review#^f3]]
- C4: 2025-26 AI reviews converge on key moments then one fix for next game; no League
  page walks the player through moments. for: [[opgg-membership#^f2]], [[baronbuff-home#^f2]], [[loldosa-topgg#^f2]], [[mobalytics-match-ui#^f2]]
- C5: Review built to celebrate keeps players: chess.com eased Brilliant, players
  spend free reviews on wins, Leetify pitches best plays. for: [[chesscom-new-game-review-2022#^f1]], [[gothamchess-truth-game-review#^f10]], [[leetify-lol-rating#^f6]]
- C6: Rivals show thin data as a bare count at best, put 2-game rows on top and are
  mocked for it. for: [[fdg-ugg-app-review#^f3]], [[ugg-darius-counter#^f13]], [[reddit-ugg-is-so-bad#^f2]], [[opgg-help-rip-champion#^f1]]
- C7: Rare champion-roles win about 39% the next week and no counter or duo stands out
  once thin pairings are pulled in. for: [[meiolol-learned-tools#^f1]], [[meiolol-learned-tools#^f2]]
- C8: Big tools have no patch-day rule; last month's numbers with a small per-patch
  offset beat the new patch's own early on. for: [[ugg-garbagemen-reply#^f2]], [[draftgap#^f30]], [[meiolol-learned-tools#^f6]], [[meiolol-learned-tools#^f8]]
- C9: Rival benchmarks are against a tier (Blitz in game) or a 15 minute snapshot; no
  leader draws a matchup lead over time. for: [[blitz-lol#^f13]], [[mobalytics-darius-vs-garen#^f6]], [[lolalytics-darius-vs-garen#^f7]], [[leagueofgraphs-darius-stats#^f8]]
- C10: Progress tracking and recaps are what brings players back and what paid tiers
  sell. for: [[mobalytics-plus#^f4]], [[mobalytics-smart-highlights#^f3]], [[leetify-improve-guide#^f2]], [[lol-yearin-wrapped#^f2]]
- C11: At low and mid elo experience on a champion matters more than counters; only
  LoLTheory adjusts for it. for: [[lol-mastery-analysis#^f1]], [[ss-dont-counterpick-unfamiliar#^f1]], [[loltheory-what-is#^f4]]
- C12: Riot values social, shareable features; rivals' friend features are thin and
  paid (U.GG's Discord leaderboard). for: [[riot-api-challenge-2018#^f2]], [[riot-rift-rewind-2025#^f3]], [[ugg-plus#^f2]]
- C13: None of the big six publishes method or accuracy for champ select advice; Riot
  weighs method write-ups. for: [[opgg-help-tier-calc#^f5]], [[itero-winrate-usefulness#^f8]], [[riot-api-challenge-2018#^f5]]
- C14: Pre-game screens move to fewer numbers; players check the lane opponent first.
  for: [[itero-update-v3-10#^f1]], [[yt-stop-loading-stats#^f2]], [[reddit-lookup-stats-sentiment#^f3]]
- C15: A rank looked up after the game inflates high-rank win rates; no rival says
  when it reads rank. for: [[meiolol-learned-tools#^f5]]
- C16: Riot removed enemy cooldowns, spike alerts and decision prompts (Aug 2025), yet
  some vendors still ship them. for: [[overwolf-aug-2025-riot-guidelines#^f2]], [[overwolf-aug-2025-riot-guidelines#^f3]], [[opgg-help-desktop#^f15]], [[yourgg-membership#^f5]]
- C17: Names in ranked champ select hidden since 12.22; auto-accept gone from all apps.
  for: [[riot-champ-select-anon-apps-1222#^f1]], [[itero-companion-apps#^f5]]
- C18: Per-option rune and build win rates are mostly noise; champ select runes don't
  detectably move the win. for: [[meiolol-learned-tools#^f3]], [[meiolol-learned-tools#^f4]]
- C19: AI coaching launches metered, the funded standalone voice coach vanished, uplift
  claims are unbacked, and Riot capped replay downloads over AI-built scrapers.
  for: [[yourgg-membership#^f1]], [[gamesbeat-clout-kitchen#^f1]], [[mobalytics-home#^f4]], [[lol-patch-26-21#^f4]], [[lol-patch-26-21#^f5]]
- C20: No account and no Overwolf are praised; forced login drew complaints.
  for: [[porofessor-standalone-reddit#^f6]], [[lol-recorder-no-overwolf#^f2]], [[overwolf-itero#^f9]]

## Disagreements

Praise vs honesty (postgame-review-compare): chess.com flatters, STRATZ chose honesty;
no source measures which keeps players longer. Our line: praise only what the numbers
back (a fight that moved win chance), never a grade.

## Open

- Whether a guided walk fits Your games' one-page layout or needs its own view (UI run)
- Rank as at the game in every filter: check site rank filters against learned.md
- Source detail behind each item: [[champselect-advice-methods]],
  [[postgame-review-compare]], [[league-tools-2025-2026]]
