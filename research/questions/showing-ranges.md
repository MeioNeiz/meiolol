---
status: answered
priority: now
area: ui
tags: [ux/uncertainty, ux/trust, ux/features, tools]
description: How do stat sites, forecasters and experiment tools show uncertainty and thin data to lay readers, and what does research say works?
---
# How do stat sites, forecasters and experiment tools show uncertainty and thin data to lay readers, and what does research say works?

Feeds: method page (/private/truth, E9), how 80% ranges and thin cells show on meio.lol

## Answer

No League or Dota stat site checked shows a range on any number: thin data gets a games
floor, a games column or fading, and lists sort by raw win rate so the thinnest rows sit
at the extremes; showing honest ranges at all would set meio.lol apart (C1, C2). Sports
projections (ZiPS, PECOTA) publish exactly our range, 10th to 90th percentile, and
explain it by counting how often outcomes fall outside, yet readers still take the
headline as a verdict (C3, C4). Forecasters grade themselves in public on calibration
plus skill against a named baseline and admit timid forecasts; their method pages lead
with that track record, then a dated changelog, scope limits and open data (C5, C6).
FanGraphs teaches that reliability builds gradually per stat, with no single cut-off
(C7). Experiment tools headline one probability or interval in green, red or grey and
keep risk behind a detail (C8).

Research on lay readers: two ranges side by side do not tell readers how often A beats
B (errors of 36 points or more), and confidence-style ranges make them overstate how
often the better option wins, worst for small effects, which is every League gap (C9,
C10). Counts ("8 in 10") beat percentages and a 20-dot quantile dotplot beats a density
(C11). A lone interval in words is fragile, and hard-edged bars are read as categories
and their ends as real values; colour fading to grey as uncertainty grows makes readers
weigh it (C12, C13). Capped bars are read as in or out and inflate gaps; gradients
remove that bias (C16). Readers compare centres and underestimate how often A wins
whatever the display (C18). Products that keep thin numbers in view hatch, wash or count
them and keep the raw value (C19); motion with no explanation reads as a fault (C20).

So, for the site (C14): keep the number, fade it towards grey by range width (J35's
solid and faded already do this), and put the 80% range and games in a plain tooltip
("about 52%; 8 in 10 chance it is 50 to 54; 1,240 games"); never a capped error bar
column. Comparisons ("A or B for you") as one sentence in games out of 100 plus a
sure / not sure word, not two ranges and not "93% chance A is better". A 20-dot dotplot
for a single number on a detail page. Sort by the estimate, not the raw rate, and keep
thin rows visible. For the method page (C15): track record first, per kind, share of
80% ranges that held next to their median width (so a too-wide range does not read as a
win), against "raw last 30 days" and "raw this patch" scored the same way; then rules
(ranges frozen before the games they are scored on), what spreads a range (luck, patch
drift, pull to the parent) one line each, games-until-half-weight per kind as a curve,
and a dated changelog of range changes.

## Claims

- C1: Major LoL and Dota stat sites show no ranges; thin data gets a games floor, a games
  column or fading, and lists sort by raw win rate. for: [[ugg-top-tier-list#^f6]], [[ugg-duo-tier-list#^f5]], [[opgg-darius-build-vs-garen#^f2]], [[opgg-darius-build#^f3]], [[dotabuff-am-counters#^f3]], [[lolalytics-counters-threshold#^f1]]
- C2 (inferred): Showing honest ranges sets meio.lol apart from every LoL and Dota site
  checked. from: C1
- C3: Sports projections publish a 10th to 90th percentile range and explain it by how
  often outcomes fall outside. for: [[fangraphs-zips-2022-percentiles#^f1]], [[bp-pecota-beyond-90th#^f1]]
- C4: Even with explanation, readers take a headline estimate as a verdict.
  for: [[fivethirtyeight-2020-design#^f1]], [[fangraphs-zips-2022-percentiles#^f2]]
- C5: Forecasters judge themselves in public on calibration plus skill against a named
  baseline, and admit timid forecasts. for: [[fivethirtyeight-checking-our-work#^f1]], [[fivethirtyeight-checking-our-work#^f2]], [[fivethirtyeight-checking-our-work#^f4]], [[economist-2020-how-this-works#^f10]]
- C6: Method pages build trust with track record, a dated changelog, scope limits, open
  data and a contact line, and name each source of spread in a plain line, saying thin
  data widens the range. for: [[fivethirtyeight-2020-forecast-works#^f1]], [[fivethirtyeight-2020-forecast-works#^f3]], [[fivethirtyeight-2020-forecast-works#^f4]], [[fivethirtyeight-2020-forecast-works#^f5]], [[economist-2020-how-this-works#^f6]], [[economist-2020-how-this-works#^f9]], [[economist-2020-how-this-works#^f11]]
- C7: Reliability builds gradually and differs per stat, so per-stat numbers beat one
  floor. for: [[fangraphs-library-sample-size#^f2]], [[fangraphs-library-sample-size#^f4]], [[fangraphs-library-sample-size#^f5]]
- C8: Experiment tools headline one probability or interval with a three-state colour
  and hide risk or expected loss behind a detail. for: [[growthbook-experiment-results#^f1]], [[statsig-read-results#^f1]], [[eppo-experiment-analysis#^f3]], [[eppo-experiment-analysis#^f4]], [[growthbook-stats-details#^f2]]
- C9: Lay readers cannot judge how often A beats B from two ranges side by side;
  animated draws or stating it does much better. for: [[hullman-hops-2015#^f1]], [[hullman-hops-2015#^f2]], [[padilla-kay-hullman-uncertainty-vis-2020#^f8]]
- C10: Confidence-style ranges make lay readers overstate how often the better option
  wins, most for small effects. for: [[hofman-inferential-uncertainty-2020#^f1]], [[hofman-inferential-uncertainty-2020#^f2]], [[hofman-inferential-uncertainty-2020#^f3]]
- C11: Counts beat percentages, and quantile dotplots of about 20 dots beat densities
  for reading one uncertain number (no gain at 100 dots). for: [[padilla-kay-hullman-uncertainty-vis-2020#^f2]], [[kay-whenish-bus-2016#^f2]], [[kay-whenish-bus-2016#^f3]], [[kay-whenish-bus-2016#^f4]], [[fernandes-quantile-dotplots-2018#^f1]]
- C12: A single interval in words is fragile: high levels blur into "certain".
  for: [[fernandes-quantile-dotplots-2018#^f3]], [[fernandes-quantile-dotplots-2018#^f4]], [[fernandes-quantile-dotplots-2018#^f5]]
- C13: Hard-edged range bars are read as categories and their ends as values; colour
  fading with uncertainty makes readers weigh it. for: [[padilla-kay-hullman-uncertainty-vis-2020#^f5]], [[padilla-kay-hullman-uncertainty-vis-2020#^f6]], [[padilla-kay-hullman-uncertainty-vis-2020#^f7]], [[padilla-kay-hullman-uncertainty-vis-2020#^f9]]
- C14 (inferred): On the site, fade by width with range and games in words on hover,
  comparisons in games out of 100 with a sure word, dotplots on detail pages, sort by
  estimate. from: C1, C9, C10, C11, C13
- C15 (inferred): The method page leads with per-kind coverage beside median width against
  both named raw modes, then rules, sources of spread, half-weight curves and a changelog.
  from: C3, C5, C6, C7
- C16: Capped range bars are read as in or out and inflate gaps between values, even by
  researchers; gradient and violin shapes remove that bias for a small gain in right calls.
  for: [[correll-gleicher-error-bars-2014#^f1]], [[correll-gleicher-error-bars-2014#^f2]], [[correll-gleicher-error-bars-2014#^f3]], [[correll-gleicher-error-bars-2014#^f4]], [[belia-ci-se-misunderstood-2005#^f2]] against: [[kale-hops-trends-2019#^f4]]
- C17: With a value-suppressing palette readers find values as accurately as with a plain
  two-variable map and avoid the least sure cells; a few discrete steps beat a smooth blend.
  for: [[correll-moritz-heer-vsup-2018#^f4]], [[correll-moritz-heer-vsup-2018#^f5]], [[correll-moritz-heer-vsup-2018#^f6]]
- C18: Lay readers judge A against B by the distance between centres and underestimate
  how often A wins with every display; dotplots err least, animated draws no better than
  intervals. for: [[kale-effect-size-strategies-2020#^f1]], [[kale-effect-size-strategies-2020#^f2]], [[kale-effect-size-strategies-2020#^f3]]
- C19: Products that keep thin numbers in view keep the raw value and mark the thinness
  by texture or wash (Savant's hatched bar) or a grey count and a word tag (Porofessor).
  for: [[savant-comparison-tool#^f2]], [[savant-comparison-tool#^f4]], [[porofessor-live-ui#^f8]], [[porofessor-live-ui#^f10]]
- C20: Uncertainty shown as motion, with no line saying what the motion means, is read as
  a trend or a fault. for: [[aisch-jittery-gauges-2016#^f4]], [[flowingdata-nyt-needle-2016#^f1]]
- C21: With thin data the NYT needle shows the prior estimate, and the widget is withheld
  where data is too thin. for: [[reuters-institute-nyt-needle-2024#^f1]], [[reuters-institute-nyt-needle-2024#^f2]]

## Disagreements

The Economist explains a range in nested words ("decent chance 51 to 52, very good
chance 49 to 54", A) while Fernandes et al find a single stated interval fragile (A).
Not a clash: nested levels and counts avoid the one-number "85%" problem. 538's ball
swarm and The Economist's bands were not user-tested (fivethirtyeight-2020-design ^f8).

## Open

- Which sure / not sure cut-off for comparisons, and is it the chance A is better or a
  minimum edge in games? Kale 2020 measures the misjudgement (C18) but proposes no cut-off.
- Display options weighed side by side for Jacob (5 Nov):
  data/team/2026-11-05-meionotes/uncertainty-options.html; decision goes in
  docs/frontend.md "Good UI here".
- Words for confidence beside dotplots: Padilla et al 2021 (Frontiers).
- Stratz is behind a login (skipped).
