---
status: answered
priority: now
area: ui
tags: [ux, ux/density, ux/colour, ux/layout, ux/charts, ux/uncertainty]
description: How dense stat sites (League and outside) lay out many numbers readably, and which ideas fit meio.lol's pages
---
# How do the best dense stat sites lay out many numbers readably, and what should meio.lol steal?

Feeds: docs/design-ideas.md (Jacob 20 Oct: "more colour", "so space inefficient",
lolalytics "not easy to read"; colour should follow what is "actually impactful")

## Answer

The sites that read well spend colour on one deciding number and leave the rest in
plain ink: u.gg, op.gg, dpm and METAsrc colour only the win rate or the difference, with
a neutral band around 50% (C1), while lolalytics spends colour on which metric a row is
and gives every number the same weight in tiny centred type (C8). On dark pages the
neutral middle should recede (a dark or grey centre, clamped labelled steps, as finviz)
so only extremes stand out (C3), and the scale should be blue against orange, not red
against green (C4). A second cue beside colour (bar length, bold leader, sign) carries
the meaning for colour-blind readers and is what FBref, Basketball Reference and
Dotabuff use (C2). Every value sits next to its sample in a fixed small grey spot, and
thin data fades (op.gg, dpm runes) (C5, C6); the most common failure across League sites
is sorting raw win rates so tiny samples lead (C7). Density comes from summaries first
(top 5 before the table, a fixed scouting summary, a pinned average row) and baselines
in the cell (last patch under the value) rather than more columns (C9, C10). Win
probability charts give each side one end of a 0 to 100 axis and list the key moments
underneath; chess reviews name swings in bands finer near zero (C11, C12). Policy: word
labels with games (dpm's Good Lane, iTero's Safe) are the safe form of dpm's "+4.9%"
chips (C13). meio.lol's own impact measurements for what to colour are in
docs/design-ideas.md and docs/learned.md (20 Oct), not here.

## Claims

- C1: Dense League sites colour only the one deciding number, and only outside a neutral band around 50%. for: [[ugg-darius-matchups#^f2]], [[opgg-darius-build#^f2]], [[metasrc-darius#^f2]], [[dpm-darius#^f4]]
- C2: Readable dense tables mark "is this good" with a second cue beside the number (bar length, bold, underline), not colour alone. for: [[fbref-salah-scout#^f2]], [[bbref-jokic#^f1]], [[dotabuff-match#^f2]], [[dotabuff-am-counters#^f2]], [[okabe-ito-cud#^f5]]
- C3: On a dark background, heat maps use a dark neutral centre and a clamped, labelled set of steps, so average values recede and extremes stand out. for: [[finviz-map#^f1]], [[finviz-map#^f2]], [[crameri-misuse-colour-2020#^f5]]
- C4: A diverging win-rate scale should be blue and orange, not red and green. for: [[crameri-misuse-colour-2020#^f1]], [[crameri-misuse-colour-2020#^f2]], [[okabe-ito-cud#^f1]], [[okabe-ito-cud#^f3]] against: [[finviz-map#^f1]], [[fbref-salah-scout#^f2]]
- C5: Every value sits next to its game count in a fixed small grey spot. for: [[ugg-darius-counter#^f7]], [[ugg-darius-build#^f1]], [[opgg-darius-build#^f1]], [[dpm-darius#^f1]], [[fbref-salah-scout#^f4]]
- C6: Fading rarely picked options is an established thin-data cue. for: [[opgg-darius-build#^f3]], [[dpm-darius#^f3]]
- C7: The most common failure is sorting by raw win rate with no shrinkage or flag, so tiny samples lead. for: [[deeplol-darius#^f3]], [[ugg-top-tier-list#^f6]], [[leagueofitems-darius#^f4]], [[opgg-darius-build#^f5]], [[leagueofgraphs-darius-counters#^f4]]
- C8: LoLalytics is dense but hard to read: colour encodes metric identity, not size; every number has equal weight; condensed centred 11-12 px figures; unexplained Delta 1 and Delta 2. for: [[lolalytics-darius-build#^f4]], [[lolalytics-darius-build#^f5]], [[lolalytics-darius-build#^f8]], [[lolalytics-darius-build#^f12]]
- C9: Answer first, detail second: top 5 lists before the full table, a fixed summary before the full report, a pinned average row. for: [[dotabuff-am-counters#^f1]], [[fbref-scouting-explained#^f2]], [[fbref-pl-stats#^f2]], [[mobalytics-darius-counters#^f1]], [[leagueofgraphs-darius-counters#^f1]]
- C10: A baseline inside the cell (last patch's value or the change under the number) adds context without columns. for: [[leagueofitems-darius#^f1]], [[dpm-tier-list#^f1]], [[opgg-tier-list#^f2]]
- C11: Two-sided win-probability charts use one line on 0 to 100, each side owning one end, with the area to 50 shaded and key moments listed under it. for: [[espn-nfl-gamecast#^f1]], [[espn-nfl-gamecast#^f2]], [[espn-nfl-gamecast#^f5]]
- C12: Game reviews name each swing by how much win chance it lost, in bands finer near zero. for: [[chesscom-move-classification#^f3]], [[lichess-accuracy#^f2]]
- C13 (inferred): Word labels with games beside them are the policy-safe form of signed win-rate chips. from: C1, C5
- C14: Very compact forms worth copying: skill order as a 4 by 18 grid of squares, role share under each role icon in the filter. for: [[lolalytics-darius-build#^f7]], [[lolalytics-darius-build#^f1]], [[dpm-darius#^f5]]
- C15 (inferred): meio.lol should use one blue and orange diverging scale with a receding neutral and vivid clamped ends, the sign or a bar as the second cue. from: C2, C3, C4

## Disagreements

- Red and green (C4): finviz and FBref still use them, readable because the sign or the
  bar repeats the colour. Settles nothing for us: we are dark and already blue/orange.
- Number colour or cell fill: u.gg and op.gg colour the number; finviz, FBref and
  Mobalytics colour the cell or row. Fill shows magnitude from further away; coloured
  numbers keep the table quiet. docs/design-ideas.md picks fills for heat-map tables
  and coloured numbers elsewhere.

## Open

- No chess review screenshots (chess.com needs sign-in, lichess analysis not found
  public); Stratz behind a login wall
- Hallway test of the proposed scale with a colour-blind player beats more reading
