---
status: answered
priority: soon
area: stats
tags: [method/dynamics, stats]
parent: patch-transfer
description: How do others predict a champion's (hero's, deck's) win rate in a new patch's first days, before games pile up, and which of their methods are worth a declared test on 16.23?
---
# How do others predict a champion's (hero's, deck's) win rate in a new patch's first days, before games pile up, and which of their methods are worth a declared test on 16.23?

Feeds: docs/plan/patch-transfer.md "Methods from prior art, for a declared 16.23 test"; Meio's patch
offset d[cr, patch] (docs/plan/estimates.md), P3 (data/team/2026-11-13-max/meio2.md).
Builds on [[patch-transfer]] (how to train across patches), [[frontier-dynamics]] C5-C9
(Riot's band, buff counts predict poorly, launch learning), [[context-aware-models]] C8-C9
(a known break is a variance step plus reversion) and [[champselect-advice-methods]] C8
(big tools state no patch-day rule).

## Answer

Nobody we found forecasts a patch's win-rate moves and scores the forecast out of sample.
Stat sites do not estimate through a patch at all: they reset to the new patch's own
games or show an unweighted day window, with sample floors or blanks, and curated
reports wait about a week (C1, C2). The only stated blends are hobby-sized: DraftGap's
1,000 pseudo-games toward 30 days and one Deadlock site's hand-set 15,000 (4,000 for a
changed hero) (C3). So Meio's pooled fit with a shrunk patch offset has no counterpart
on the big sites; the bars to beat stay their two raw modes, which E2 scores (C13).

Forecasting practice elsewhere says the form is right. Old periods plus a thin new one
is count addition with a fixed pad, one per stat, and the pad is best fitted by forecast
error (C4, C5); a good prior keeps most of the weight for months, less for units likelier
to have changed (C6). Meio's ~70% lean on older patches at day 0 and its fitted offset sd
(a pad of 7,000-10,000 games per champion-role) sit inside that practice (C13). A known
break is a variance step for every unit plus a mean shift only where outside knowledge
gives one (C7); we have the step, and A3 showed a per-champion step adds nothing (C12).

The open part is the mean shift. Riot sizes changes in win-rate points internally but
publishes no list, and the designer previews have ended (C8). Notes give the sign
reliably and cheaply, sizes poorly, and item or rune changes not at all without build
exposure (C9). One in-sample backtest got the sign right 72-74% and cut absolute error
16% against no change with forecast = k x notes score (C10). Against it: buffs miss
more than nerfs because new pickers arrive, knock-on moves are not predictable even by
simulation, and card-game day-one rates reverse (C11, C14). How fast a move settles has
no measured answer anywhere; designers and sites say days to a week for builds and
reworks, and our 16.21 check found no curve for number changes (C12, C14).

Search state: 31 searches. Stat-site rules slowing (the last four found only observable
defaults); patch-note forecasts slowing (late hits were 0-star parsers); hierarchical
models across patches in other games saturated (3 more searches found nothing new).

## Claims

- C1: Stat sites handle a new patch with a hard per-patch reset or an unweighted rolling window, plus sample floors or blanks; none of the big ones states a blend or prior. for: [[overwatch-hero-statistics#^f1]], [[overwatch-hero-statistics#^f2]], [[overwatch-hero-statistics#^f4]], [[lolalytics-days-window#^f2]], [[lolalytics-days-window#^f4]], [[d2pt-meta#^f1]], [[d2pt-meta#^f3]], [[d2pt-meta#^f5]], [[metabot-patch-25-22#^f1]]
- C2: Curated data reports wait about a week after a balance patch rather than estimate through it, and Riot's own balance team reads a before/after table it calls misleading early. for: [[vs-data-reaper-2025-07#^f1]], [[vs-data-reaper-2025-07#^f2]], [[vs-data-reaper-327#^f1]], [[devtrackers-11-2-11-3-winrate-changes#^f1]], [[devtrackers-11-2-11-3-winrate-changes#^f2]]
- C3: Where a blend with older data is stated, it is a fixed count of pseudo-games set by hand: 1,000 toward 30 days (DraftGap), 15,000 or 4,000 for a changed hero (meta-unbound). for: [[draftgap#^f30]], [[meta-unbound-patch-forecast#^f3]], [[meta-unbound-patch-forecast#^f10]]
- C4: The standard forecast from old periods plus a thin new one is count addition: (new counts + w x old counts + K x mean) / (n_new + w x n_old + K), w a fixed decay per period (Marcel 0.8) and K a fixed pad, so the weight on new data is n / (n + pad). for: [[tango-marcel-2004#^f1]], [[tango-marcel-2004#^f2]], [[tango-marcel-2004#^f3]], [[kmedved-padding-2020#^f1]], [[kmedved-padding-2020#^f2]]
- C5: The pad is best chosen by forecast error from every point in the period, one per stat; it differs several-fold between stats and came out a third of the reliability-formula value. for: [[kmedved-padding-2020#^f4]], [[kmedved-padding-2020#^f5]], [[kmedved-padding-2020#^f6]]
- C6: A prior built on old periods keeps most of the weight (57-69%) against months of new data, more for noisier stats and less for units likelier to have changed. for: [[fangraphs-preseason-projections-still-matter#^f1]], [[fangraphs-preseason-projections-still-matter#^f2]], [[fangraphs-preseason-projections-still-matter#^f3]]
- C7: A known break is modelled as added variance for every unit plus a mean shift only where outside knowledge gives one; the variance step is robust, the mean shift is the hard part. for: [[queen-albers-2009-intervention-mdm#^f1]], [[queen-albers-2009-intervention-mdm#^f3]], [[queen-albers-2009-intervention-mdm#^f5]], [[lopez-2018-best-team-win#^f1]]
- C8: Riot sizes single changes in win-rate points (0.5-0.75 for one example), aims for small effects and corrects misses the next patch, but publishes no per-patch list of expected sizes; the designer preview videos gave none and have ended. for: [[phreak-devtrackers-profile#^f1]], [[phreak-devtrackers-profile#^f3]], [[phreak-devtrackers-profile#^f5]], [[phreak-patch-26-07-preview#^f1]], [[phreak-patch-26-07-preview#^f5]], [[riot-balance-framework-update#^f2]]
- C9: A patch note's direction can be coded reliably before any games (87-99% agreement); a 1-3 size agrees 75% and is unvalidated; item and rune changes cannot be assigned to champions by a coder, and game data misses changes the notes state. for: [[late-patches-worlds-2026#^f3]], [[late-patches-worlds-2026#^f4]], [[late-patches-worlds-2026#^f5]], [[late-patches-worlds-2026#^f6]], [[meiolol-learned-patch#^f5]]
- C10: No forecast of per-champion patch win-rate moves has been scored out of sample; the one backtest (forecast = k x signed notes score, k from past patches) is in-sample: sign right 72-74%, absolute error 16% under no change, 43 and 53 points. for: [[meta-unbound-patch-forecast#^f1]], [[meta-unbound-patch-forecast#^f5]], [[meta-unbound-patch-forecast#^f6]], [[meta-unbound-patch-forecast#^f8]], [[late-patches-worlds-2026#^f10]], [[itero-tier-list-results-12-11#^f4]] against: [[kica-claypool-lol-patches#^f4]], [[late-patches-worlds-2026#^f8]]
- C11: The label gives the sign better for nerfs than buffs (7 of 8 against 5 of 9 on one patch), since a buff draws new pickers and unlearnt builds; knock-on moves of unchanged pieces were not forecast even with a simulator. for: [[review-patch-10-12-by-numbers#^f2]], [[review-patch-10-12-by-numbers#^f3]], [[devtrackers-11-2-11-3-winrate-changes#^f3]], [[phreak-patch-26-07-preview#^f3]], [[deadlock-api-2026-patches-meta-shift#^f2]], [[meta-discovery-balance-2024#^f2]], [[meta-discovery-balance-2024#^f3]]
- C12: On our games (16.21) a looser prior for changed champions adds nothing over one estimated offset sd, no rank or region leads, and a number change shows no settling curve; mean reversion at the boundary is only a hint. for: [[meiolol-learned-patch#^f1]], [[meiolol-learned-patch#^f2]], [[meiolol-learned-patch#^f3]], [[patch-jump-16-21-measured#^f3]]
- C13 (inferred): Meio's day-0 lean (~70% older patches) and its offset pad (7,000-10,000 games) are within forecasting practice, and stronger than any stated stat-site blend; the bars to beat are the sites' two raw modes. from: C1, C3, C4, C6, C12
- C14: First-days rates can come from a different population, field or game: card-game day-one rates reversed within a week, a set's headline number halved after a day of normal games, and a rework was hotfixed within a day with Riot expecting it to rise. for: [[vs-data-reaper-327#^f3]], [[vs-data-reaper-327#^f4]], [[vs-data-reaper-327#^f5]], [[mtgazone-one-week-one-data#^f1]], [[mtgazone-one-week-one-data#^f2]], [[sierkovitz-17lands-early-data#^f3]], [[ugg-shyvana-rework-hotfix-26-06#^f1]], [[ugg-shyvana-rework-hotfix-26-06#^f2]] against: [[meiolol-learned-patch#^f3]]
- C15 (inferred): Worth a declared 16.23 test: a signed mean for directly changed champions (sign from the notes, one fitted size per sign), the pad per kind fitted by forecast error against the MacKay sd, and a micropatch as its own boundary; not worth one: designer sizes, 1-3 size labels before the sign passes, knock-on means, a changed-champion variance, waiting for data. from: C5, C7, C9, C10, C11, C12, C14

## Disagreements

- Does a notes score predict the move? meta-unbound's in-sample backtest says yes (D);
  Kica-Claypool's buff counts say poorly (C) and Kwak's coded exposure is null in pro
  play (C, wide interval). Counts ignore sign and size, pro play is another outcome:
  option 1's test on 16.23 settles it for us.
- Day-one bias: designers, card-game analysts and a reddit thread say first-days rates
  understate a buffed or reworked unit (B to D, no sizes); our 16.21 check found a
  jumped pick about a point up from the start and no curve (B, one patch, number
  changes only). Reworks and new champions are the likely exception (frontier-dynamics
  C7).

## Options

| Option | Claims for | Claims against | Would change if |
| --- | --- | --- | --- |
| 1 Signed mean: offset mean = sign x m for directly changed champions | C7, C9, C10 | C11, C8 (intended sizes under a point) | 16.23 days 0-1 show no gain over mean 0 |
| 2 Pad per kind by forecast error | C4, C5, C6 | PT3's sd grid: the estimated sd already near best | fitted pad within 2x of MacKay's on both replays |
| 3 Micropatch as its own boundary | C14 | rare; none may fall in 16.23 | no mid-patch update in the notes |
| 4 Mean reversion: changed champions move back toward their role's middle | C8 (misses corrected), late-patches #^f9 | C12 (a hint on 12 champions), context-aware-models C9 | slope on 16.21 and 16.22 within the control's |
| 5 Size from the notes (1-3 or number diffs) | C10 | C9 (75%, unvalidated), C11 | only after option 1 passes |
| Not tested: designer sizes, knock-on means, changed-champion variance | | C8, C11, C12 | Riot publishes sizes |

## Open

- What LoLalytics, U.GG and OP.GG show by default on a patch's day 0 and day 1: no
  archive capture found; snapshot them on 16.23's first two days.
- Phreak's 2023-2025 rundowns: did they give numeric sizes that could be scored (lead)?
- A measured day-by-day course of win rate after a plain buff or nerf: none found in any
  game; our TS4 on 16.22 and 16.23 would be the first.
- The patch correlation rho across the boundary against a same-length gap inside a patch
  ([[tht-regression-changing-talent#^f4]]): a cross-check on the offset sd, not yet run.
- Not read: Dorhauer "Elo vs. Regression to the Mean", the Claypool journal version, a
  17Lands issue with a fitted beta prior for new cards, Counterwatch's shrinkage post
  (leads).
