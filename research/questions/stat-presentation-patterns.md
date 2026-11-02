---
status: answered
priority: now
area: ui
tags: [ux/density, ux/features, ux/layout]
description: How do stats sites present duos, a figure's rank among all, a summary in words from numbers, and dense tables on phones, and which components carry them?
---
# How do stats sites present duos, a figure's rank among all, a summary in words from numbers, and dense tables on phones, and which components carry them?

Feeds: 2 Nov polish run proposals (data/team/2026-11-02-polish/notes/meiolol-research-ui.md); docs/plan/ui/rankings.md, champion.md (words layer, trend), pairlane.md, champions.md

## Answer

Duos: the shipped pair row is both solo win rates beside the pair's and one signed gain,
the pair minus the mean of the two solos (u.gg Synergy Factor, LoLalytics Synergy
Delta) (C1); LoLalytics adds a normalised gain so two strong champions don't read as a
synergy (C2). Thin pairs are cut by a floor, never marked; Basketball-Reference sorts
pairs by time together, which keeps thin ones down by construction, and ends the table
with a baseline row (C3, C5). No site has a page for one pair or a partner picker (C4):
that, and a pair's lane curve, is open ground.

Place among all: the page shows a compact summary (Savant's percentile sliders, bbref's
"value (13th)", op.gg's "17th / 61" per point) that links to a full board with a rank
column (C6). Thin samples are kept out by a printed qualifier and get a blank, not a
shaky place (C7); ties are shared plainly (C8). Nobody highlights or scrolls to the
reader's row, so our #slug highlight is ahead (C9).

Words: generated summaries are templates with slots filled from numbers, picking facts
by rank, extreme or change against a baseline (C10); they cap how much they say and stay
silent when nothing stands out (C11). No source gives a sample-size rule for wording;
GA4 only flags a change outside an interval from history, the model for "say it only
when the interval clears the role average" (C12).

Phone tables: sticky header and first column with a visible cue (a cut-off column, not
dots) (C13); cards per row or hidden columns avoid sideways scroll but cost comparison
(C14); Sports Reference compares far-apart rows by isolating chosen rows (C15).
Hover-only sort icons leave touch readers blind (C16). How sort is changed on a phone:
no source says.

Trends over days (store, 22-24 Oct): Dotabuff puts an 8-point daily sparkline with
min and max labels in every row; op.gg labels each patch point with a rank; neither
shows samples, and op.gg's 48-52% axis makes a point look like a cliff (C17, C18).

## Claims

- C1: Pair rows show both solo rates, the pair rate and a signed gain (pair minus the mean of the solos). for: [[ugg-duo-tier-list#^f1]], [[ugg-duo-tier-list#^f3]], [[lolalytics-synergy#^f2]]
- C2: A normalised gain guards against two strong champions looking like synergy. for: [[lolalytics-synergy#^f3]]
- C3: Thin pairs are cut by a floor, not marked; ordering by sample keeps them down by construction. for: [[ugg-duo-tier-list#^f5]], [[bbref-celtics-lineups#^f2]], [[bbref-celtics-lineups#^f3]]
- C4: No site has a page for one pair or a partner picker; the pair lives in a champion's tab or a board row. for: [[ugg-duo-tier-list#^f8]], [[ugg-duo-tier-list#^f9]], [[lolalytics-synergy#^f5]], [[bbref-celtics-lineups#^f6]], [[bbref-celtics-lineups#^f7]]
- C5: A baseline row or line (team average, MLB) gives signed numbers their zero. for: [[bbref-celtics-lineups#^f4]], [[savant-percentiles#^f11]]
- C6: A figure's place is a compact summary on the page that links to a full board with a rank column. for: [[savant-percentiles#^f1]], [[savant-percentiles#^f5]], [[bbref-jokic#^f5]], [[bbref-leaders-pts#^f4]], [[opgg-darius-trends#^f1]]
- C7: Thin samples get no place: a printed qualifier and a blank cell. for: [[savant-percentiles#^f3]], [[savant-percentiles#^f4]], [[fbref-scouting-explained#^f3]]
- C8: Ties are shared plainly (repeated value, blank rank cell). for: [[savant-percentiles#^f6]], [[bbref-leaders-pts#^f2]]
- C9: Neither Savant nor Basketball-Reference highlights the reader's row on the board. for: [[savant-percentiles#^f13]], [[bbref-leaders-pts#^f6]]
- C10: Summaries in words are templates filled from numbers, choosing facts by rank, extreme or change. for: [[powerbi-smart-narrative#^f1]], [[powerbi-smart-narrative#^f3]], [[lolalytics-darius-build#^f2]], [[mobalytics-darius-counters#^f5]], [[content-selection-d2t-survey#^f2]]
- C11: Generators cap what they say and leave a slot empty when nothing stands out. for: [[powerbi-smart-narrative#^f2]], [[powerbi-smart-narrative#^f4]], [[content-selection-d2t-survey#^f2]]
- C12 (inferred): State a comparison only when it clears an interval and a size floor, as GA4 flags anomalies. from: C11 for: [[ga4-anomaly#^f1]], [[ga4-anomaly#^f2]]
- C13: Phone tables: sticky header and first column, scroll shown by a cut-off column or arrows. for: [[nng-mobile-tables#^f3]], [[nng-mobile-tables#^f4]], [[nng-mobile-tables#^f5]], [[datawrapper-table-academy#^f3]]
- C14: Cards per row and hidden columns avoid sideways scroll at the cost of comparing rows. for: [[datawrapper-table-academy#^f1]], [[datawrapper-table-academy#^f2]], [[nng-mobile-tables#^f6]]
- C15: Comparing far-apart rows: select rows and hide the rest. for: [[sportsref-row-isolation#^f1]]
- C16: Hover-only sort icons give touch readers no sign of which columns sort. for: [[carbon-data-table#^f1]]
- C17: Daily trend in a table is a per-row sparkline with min and max labelled. for: [[dotabuff-hero-trends-ui#^f2]], [[dotabuff-hero-trends-ui#^f1]]
- C18: Trend charts without samples and with a tight axis overstate small moves. for: [[opgg-darius-trends#^f3]]

## Disagreements

- Thin data: rivals cut (u.gg floor, Savant blank); meio.lol fades and folds behind
  "+N unsure". Cutting hides the champion a reader came for; fading keeps it. No source
  measured either.

## Open

- How sort is changed on a phone (no source); column priority rules
- A single pair's page: nobody has one, so no prior art beyond our matchup page
- Wording that carries uncertainty (weather text rules, [[content-selection-d2t-survey#^f4]]) unread
