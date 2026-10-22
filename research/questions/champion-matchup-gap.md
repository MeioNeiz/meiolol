---
status: answered
priority: now
area: ui
tags: [ux/features, ux/density, ux/layout]
description: Section by section, what do the leading sites show on champion and matchup pages that meio.lol lacks, and where is our layout less space-efficient or clearer than theirs?
---
# Section by section, what do the leading sites show on champion and matchup pages that meio.lol lacks, and where is our layout less space-efficient or clearer than theirs?

Feeds: docs/plan/site.md "Champion page" and "Matchup page", docs/champion-matchup.md
(Jacob 22 Oct: match lolalytics and others on champions and matchups; where our UI is
space inefficient, unclear, sub par). Extends [[dense-stat-layout]] (colour and density,
20 Oct). Our own pages measured the same day: docs/champion-matchup.md "Ours, measured".

## Answer

Champion page: the leaders' strength is a complete build on the first screen in one
compact panel. LoLalytics fits skill priority, spells, a 4x18 skill order, both rune
trees, start, core and two or three options each for items 4, 5 and 6, every one with
win rate and games, into 330 px; Blitz does the same (C1). Sections three or more sites
carry that we lack: item options by slot after the core, the full level 1 to 18 skill
order, build variants, win rate and pick rate over patches or days, win rate by game
length, and duos by ally role (C2, C3, C4). LoLalytics and OP.GG also show counters
against every enemy role, not only the lane (C3). Our stats file already holds those
ally and enemy pairs, so those two sections need no new data. Their first screens are
not as dense as they look: U.GG's build page shows about 10 numbers above the 1080p
fold and OP.GG's build starts at y 815 under ads and banners (C14). We beat both of
those but lose to LoLalytics' build panel, because ours spends a 420 px card on the
player histogram and puts the build in big cards with two icons each.

Matchup page: no leader has a real matchup page. LoLalytics, U.GG, OP.GG, Blitz and
League of Graphs make the opponent a filter on the build page and show no lane stats
(C5). What they do have that we lack is the whole build refiltered to the pair: spells,
items 4 to 6, the skill order and runes, each with its own sample (C7). The
second-tier sites show lane stats only as snapshots at 15 minutes plus level 2 and
first blood (C6). Nobody draws lane leads over time, nobody covers the support in a bot
lane matchup, and matchup tips are either paid or written for the champion in general
(C6, C11, C12). So our curves, head to head and lean facts are already ahead. The gaps
are the build depth, a visible way to switch opponent (C10), and lane and game win rate
as separate answers (C13).

What not to copy: thin matchup builds printed like solid ones (100% on 2 to 4 games,
C8), unlabelled flips of whose win rate a column holds (C9), raw win-rate sorting
(C15), colour by metric and no phone layout ([[dense-stat-layout]] C8).

## Claims

- C1: LoLalytics and Blitz put the whole build (skills, spells, runes, start, core, later item options) with win rate and games on the first 1920x1080 screen in one compact panel. for: [[lolalytics-darius-build#^f17]], [[lolalytics-darius-build#^f26]], [[blitz-darius-vs-garen#^f1]] against: [[ugg-darius-build#^f7]], [[opgg-darius-build#^f8]]
- C2: Item options by slot after the core (4th, 5th, 6th) and the full levelled skill order are standard build sections. for: [[lolalytics-darius-build#^f17]], [[opgg-darius-build#^f10]], [[ugg-darius-build#^f9]], [[ugg-darius-build#^f3]], [[opgg-darius-build#^f6]], [[opgg-darius-skills#^f1]]
- C3: Leaders show duos by ally role and counters against every enemy role, not only the lane opponent. for: [[lolalytics-darius-build#^f20]], [[lolalytics-darius-counters#^f6]], [[opgg-darius-synergies#^f1]], [[deeplol-darius#^f1]]
- C4: Trends over patches or days and win rate by game length are common champion sections. for: [[lolalytics-darius-build#^f19]], [[lolalytics-darius-build#^f25]], [[opgg-darius-trends#^f1]], [[opgg-darius-trends#^f2]], [[leagueofgraphs-darius-vs-kled#^f5]]
- C5: No leader has a matchup page with lane stats: the opponent is a filter on the build page. for: [[lolalytics-darius-vs-garen#^f7]], [[lolalytics-darius-vs-garen#^f15]], [[ugg-darius-vs-garen#^f1]], [[ugg-darius-vs-garen#^f6]], [[opgg-darius-vs-garen#^f6]], [[blitz-darius-vs-garen#^f7]], [[leagueofgraphs-darius-vs-kled#^f1]]
- C6: Lane stats where they exist are snapshots at 15 minutes plus early events (level 2, first blood); none draws a lead over time. for: [[mobalytics-darius-vs-garen#^f6]], [[metasrc-darius-counters#^f3]], [[metasrc-darius-counters#^f4]], [[leagueofgraphs-darius-vs-kled#^f2]], [[ugg-darius-matchups#^f1]]
- C7: A matchup view refilters the whole build to the pair, each section with its own sample. for: [[ugg-darius-vs-garen#^f3]], [[opgg-darius-build-vs-garen#^f1]], [[lolalytics-darius-vs-garen#^f3]], [[blitz-darius-vs-garen#^f2]], [[leagueofgraphs-darius-vs-kled#^f3]]
- C8: Matchup-filtered builds show thin options like solid ones (100% on 1 to 4 games), or silently fall back to champion-wide numbers. for: [[lolalytics-darius-vs-garen#^f12]], [[lolalytics-darius-vs-garen#^f13]], [[opgg-darius-build-vs-garen#^f2]], [[ugg-darius-vs-garen#^f4]], [[leagueofgraphs-darius-vs-kled#^f4]]
- C9: Whose win rate a list holds flips without a label between or within pages. for: [[ugg-darius-counter#^f12]], [[mobalytics-darius-vs-garen#^f8]], [[mobalytics-kaisa-vs-jinx#^f4]], [[blitz-darius-counters#^f4]]
- C10: Switching opponent is a visible list or VS block on the page: a master-detail list (OP.GG, METAsrc) or the opponent in the filter bar (LoLalytics). for: [[opgg-darius-vs-garen#^f1]], [[opgg-darius-counters#^f12]], [[metasrc-darius-counters#^f1]], [[lolalytics-darius-vs-garen#^f9]]
- C11: No site shows supports or the 2v2 on a bot lane matchup page. for: [[mobalytics-kaisa-vs-jinx#^f2]], [[lolalytics-kaisa-vs-jinx#^f3]]
- C12: Matchup tips are paid, user-written and empty, or champion-wide text. for: [[mobalytics-darius-vs-garen#^f9]], [[mobalytics-darius-guide#^f5]], [[blitz-darius-vs-garen#^f4]], [[opgg-darius-vs-garen#^f5]]
- C13: Lane result and game result as separate answers per opponent (lane win rate or gold at 15 beside game win rate). for: [[blitz-darius-counters#^f3]], [[ugg-darius-counter#^f1]], [[ugg-darius-counter#^f4]]
- C14: The big sites' first screens are chrome-heavy: ads, app banners and tips push the build or matchup data down 300 to 800 px, and phones show no data at all. for: [[ugg-darius-build#^f7]], [[ugg-darius-build#^f8]], [[opgg-darius-build#^f8]], [[opgg-darius-vs-garen#^f7]], [[metasrc-darius-counters#^f8]], [[lolalytics-darius-build#^f27]]
- C15: Sorting opponents by games puts the common lanes first; sorting by raw win rate puts the thinnest samples at both ends. for: [[metasrc-darius-counters#^f2]], [[opgg-darius-counters#^f12]] against: [[ugg-darius-counter#^f13]], [[deeplol-darius#^f3]], [[mobalytics-kaisa-vs-jinx#^f5]]
- C16: Item rows can carry the minute bought or the win rate before the purchase, separating "this item helps" from "winners buy it". for: [[lolalytics-darius-build#^f22]], [[lolalytics-darius-vs-garen#^f4]], [[blitz-darius-vs-garen#^f5]]
- C17: On a phone, putting the matchup stats first (Mobalytics) is the exception. for: [[mobalytics-darius-vs-garen#^f7]] against: [[opgg-darius-vs-garen#^f8]], [[blitz-darius-vs-garen#^f6]]
- C18 (inferred): meio.lol should adopt one compact build panel with item slots and the skill grid on the first screen, plus duos and counters by every role from the stats file it already has. On matchup pages it should refilter the full build to the pair with a thin-data cut, and keep its curves as the lead. from: C1, C2, C3, C5, C7, C8

## Disagreements

- First screen density: LoLalytics (about 70 numbers) and Blitz are dense, while U.GG
  (about 10) and OP.GG (build at y 815) are not, and both are bigger sites. Traffic
  follows search and brand ([[similarweb-u-gg#^f4]]), so density is not what wins
  players. Jacob asked for LoLalytics' density, so the plan follows him.
- Matchup tips: Mobalytics charges for them, OP.GG crowd-sources them and leaves them
  empty. Ours would be generated from data (lean facts), which neither does.

## Open

- LoLalytics' synergy tabs emptied in the headless browser, so their content wasn't seen
- League of Graphs' live site returns 403; its matchup capture is from Wayback (2023)
- METAsrc's panel category tabs weren't read
- leagueofitems and lolvvv were not read
- No player testing: which section players open first is inferred from page order and
  traffic, not observed
