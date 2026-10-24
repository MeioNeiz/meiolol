---
status: answered
priority: now
area: ui
tags: [ux, ux/postgame, ux/controls, ux/features, ux/puzzle]
description: Per UI element kind, how do other LoL (and Dota, Valorant) sites build it, what works and what doesn't, and which site should meio.lol model each on?
---
# Per UI element kind, how do other LoL (and Dota, Valorant) sites build it, what works and what doesn't, and which site should meio.lol model each on?

Feeds: docs/plan/ui/ (UI rebuild plans, team run 2026-10-24-ui); screenshots and per-kind notes in data/team/2026-10-24-ui/refs/ (gitignored)

## Answer

Per kind, the site to model on (screenshots and per-site notes in the team refs folder):
Your games on dpm.lol: compact rows with only the lane opponent, day groups with net
LP, game detail opened in the row with lane numbers at 15 against the opponent (C4,
C5); the scoreboard as lanes facing each other (Mobalytics) and one sortable table of
all ten (u.gg) (C6). No League site has a win chance curve, moments or turning points
(C1), so our chart stays, drawn the way Dota and Valorant sites draw events: icons on
the plot edges or a thin strip on the time axis, never text on the line, and a moment
picked by clicking it, not by dragging a range (C2, C3). Champion pages: lolalytics'
build panel, rune grid and skill grid, with op.gg/dpm fading for thin runes (C8),
dpm's role picker with shares (C9), and a variant list (name, games, win rate) in place
of a most-played or highest-win toggle (C7). Tables: lolalytics' sortable headers and
visible minimums; every other site keeps the role in champion links (C10). Matchups:
pick a champion, then an opponent (dpm, op.gg) (C11). Patch: nobody joins the change
text, the stat change and matchup changes (C12). Pool and draft: iTero's pool with a
shape, coverage as faces and reasons as portrait pairs; nobody shows time to learn
(C13, C14). Daily games: one sentence on the first screen, then community results
after the answer (C15). Controls: champion search that knows nicknames (u.gg, dpm),
frequent opponents first, filters as visible button groups (Dotabuff) (C16, C17).

What to leave: op.gg's "Strong pick" rank labels (C18), colour-key panels (LoLdle),
40-60 word insight cards (Mobalytics), hover-only tooltips (lolalytics).

Pick order (Daily Draft): no queue's match-v5 record has it (400, 440, 480 tested like
420); the tournament API's lobby events stop at champ select start; spectator-v5 lists
live participants in a non-role order that may be champ select order, untested;
Leaguepedia has real order for pro games (C19, C20, C21).

## Claims

- C1: No League site's game page shows a win chance curve, moments or turning points. for: [[opgg-game-detail-ui#^f9]], [[ugg-game-detail-ui#^f7]], [[dpm-game-detail-ui#^f7]], [[mobalytics-match-ui#^f10]]
- C2: Mature game sites keep the timeline line bare and put events on the plot edges or in a strip on the time axis, as game icons coloured by team. for: [[dotabuff-game-detail-ui#^f2]], [[opendota-teamfights-ui#^f1]], [[valtracker-match-ui#^f2]]
- C3: A moment is picked by clicking one fight or round, which opens its detail; no site offers drag range selection. for: [[opendota-teamfights-ui#^f2]], [[valtracker-match-ui#^f3]]
- C4: dpm compares the player with their lane opponent at 15 minutes inside the game view. for: [[dpm-game-detail-ui#^f5]], [[dotabuff-lanes-ui#^f1]]
- C5: Grouping a match history by day or session under a one-line summary keeps it readable. for: [[dpm-profile-ui#^f4]], [[deeplol-profile-ui#^f3]], [[dpm-profile-ui#^f5]]
- C6: A scoreboard with one lane per row is a lane comparison in itself; a single sortable table of all ten serves comparison. for: [[mobalytics-match-ui#^f3]], [[ugg-game-detail-ui#^f3]]
- C7: Most played and highest win rate fit in one list of variants with games and win rate each, without a toggle. for: [[blitz-champion-ui#^f1]], [[mobalytics-darius-build#^f5]], [[mobalytics-controls-ui#^f3]]
- C8: Full rune grids with per-rune numbers need fading of thin choices; lolalytics lacks it. for: [[dpm-champion-ui#^f5]] against: [[lolalytics-darius-build#^f31]]
- C9: The role picker shows the champion's share of games under each role (dpm, lolalytics). for: [[dpm-champion-ui#^f1]], [[lolalytics-darius-build#^f29]]
- C10: Leading tier lists keep the role in every champion link; meio.lol drops it. for: [[lolalytics-tierlist-top-ui#^f1]], [[dpm-tierlist-ui#^f1]], [[meiolol-champions-list-ui#^f1]]
- C11: A matchup is found by picking a champion, then an opponent, not from a list of all pairs. for: [[dpm-matchups-finder-ui#^f1]], [[opgg-darius-counters-phone-ui#^f1]]
- C12: No site shows the patch change text, the win-rate change and matchup changes together. for: [[lolalytics-home-patch-ui#^f5]], [[opgg-patch-notes-ui#^f5]], [[deeplol-darius-patch-history-ui#^f3]]
- C13: iTero gives a pool a shape (named slots) and shows coverage and reasons as portraits with scores, not tables or win rates. for: [[itero-pool-builder-ui#^f8]], [[itero-drafting-sim-ui#^f4]]
- C14: No pool tool shows how hard a champion is to learn. for: [[itero-pool-builder-ui#^f9]]
- C15: Popular daily games put about one sentence on the first screen and show community results after the answer. for: [[wordle-ui#^f1]], [[framed-ui#^f3]] against: [[loldle-classic-ui#^f5]]
- C16: Champion search that understands nicknames ("mf") and shows icons is u.gg's and dpm's; several sites lack it. for: [[ugg-controls-ui#^f5]], [[lolalytics-controls-ui#^f2]]
- C17: Filters read best as visible labelled button groups, current value shown, wrapping on phone (Dotabuff); opponent pickers put frequent opponents first (op.gg). for: [[dotabuff-heroes-ui#^f1]], [[opgg-controls-ui#^f2]], [[lolalytics-controls-ui#^f5]]
- C18: op.gg labels recommended champions "Strong pick #7", wording our rules avoid. for: [[opgg-profile-ui#^f8]]
- C19: Normal draft, flex and swiftplay match-v5 records carry no pick order, like ranked solo. for: [[meiolol-pick-order-queues#^f1]], [[meiolol-pick-order-check#^f1]]
- C20: The tournament API's lobby events end at champ select start, with no picks. for: [[riot-docs-lol#^f18]]
- C21: Pro games' pick order with roles is public in Leaguepedia; in ranked only side order is fixed (blue first, red last). for: [[leaguepedia-picksandbans#^f1]], [[lolwiki-draft-pick#^f4]]
- C22: Spectator-v5 lists live participants in a per-game non-role order. for: [[meiolol-pick-order-queues#^f3]]

## Disagreements

- Runes: lolalytics (Jacob's reference) shows every rune with numbers but no fading; dpm and op.gg fade thin runes. Take lolalytics' grid with fading (C8).

## Open

- Kinds: 1 game detail, 2 match history and profile, 3 champion page, 4 tier list, 5 matchups,
  6 patch changes, 7 pool and draft tools, 8 puzzles and daily games, 9 controls
- Player: what do I look at first after a game, and which site gets me there in one screen?
- Critic: which elements are ad-driven filler or numbers without samples?
- Maintainer: which elements recur across pages (one component, many pages)?
- Phone: which sites stay usable at 390 px, and how do they fold tables?
- Policy: which elements break our product rules (best pick, +X% win rate, names)?
- Spectator order: is it champ select cell order? Ban-repeat test in team refs pick-order.md
- Not seen: lolalytics synergy strips (empty when scripted), STRATZ (login), Blitz and
  dpm phone champion pages, Clash bans order
