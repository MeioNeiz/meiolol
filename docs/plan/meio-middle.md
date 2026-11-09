# Plan: Meio's middle, no lean, and shifts learnt from trends

What players read is the number Meio suggests, not its range. Jacob, 4 Nov: that middle
must not run high or low for any kind of cell, rare picks that really are strong
included; Meio should notice patch and meta shifts from how the data moves, not from a
change list; a simple fix beats a complex model; Meio takes far more than 30 days (LH).
Part of estimates.md (Meio, M10) and patch-transfer.md (PT8). Live state of a run:
data/team/<run>/, e.g. data/team/2026-11-04-meio/meio-model.md.

## What we know (16.21, 4 Nov; docs/model.md "Which side Meio misses on")

- Rare champion-roles win less than Meio says: about 1 point too high at log share -10.5
  (0.003% of role games), 5 at -12, 12 below -13; misses below 16% against 8% above
  for under 100 own patch games. Rare picks are mostly autofill: off-role skill sits
  about a tier under main role (research riot-dev-ranked-2019-positions)
- Keystones under ~0.25% of their champion-role: 1 to 9 points too high by rarity. A
  hinge on the champion part made it worse; suspect the role-wide main term, which
  shrinks to 0 with no popularity line
- A popularity line already exists (meio.zig fitPopularity, Cond lines); a hinge at -10
  for champion-roles helps the rare band (-2.4 milli-nats) but overshoots (misses above
  8 -> 13%): the shape is being guessed
- EUW1 Diamond+ popular champion-roles run high (pick rate over 4%: 20% below, 6%
  above); Iron-Silver the other way. Data-rich cells, so not the prior mean
- Shares: middle not biased; rising options run ahead of it, a trend term lost overall
- Patch shifts: champions sharing an item moved together after 16.21, changed or not
  (meta drift follows item groups); the ranged Hubris nerf moved its users 0.3-0.4
  points and Data Dragon's diff hid it. Champions' own changes: 1.9 points RMS day one
- Each lean is clear over a group but small against one cell's noise (0.2-0.5 sd): a
  lean is judged per group, never per cell

## Evaluation rule

- `meiolol truth` on 16.20 -> 16.21 (data/cubes-20261104b) to develop, 16.21 -> 16.22
  to confirm, its pass rule declared in docs/model.md before the look
- Gate: NL0's lean table. Beside it, paired per cell against Meio as it is: log loss per
  kind and day bucket, interval score, PIT. A change is kept when it clears a lean,
  makes no new one, and no row's log loss is worse beyond 2 se
- Trend steps (TS) are scored day by day since the patch (patch-transfer.md "Evaluation
  rule"), days 0-3 first: that is where shifts cost most. Each has a control (shuffled
  exposures, shuffled champions) that must gain nothing
- One truth run at a time on the Mac (~9 GB of 24): deploy/heavy.sh
- Logging: each experiment is a dated section at the end of docs/model.md, declared
  before the run when it is a test; a learned.md line when final; a Status line here

## No lean (NL)

- NL0 The lean table, in truth (the gate, first): later rate minus Meio's middle, in
  points, mean and se per kind x popularity band (10 bands of log share in the cell's
  bracket and window) x bracket x region; also by own-games band and day bucket. se
  over origin days (cells of one origin are not independent). Fails when a group is
  beyond 2 se and over 0.5 points (proposed: with millions of cells a 0.1-point lean is
  significant but harmless; Jacob's call). The gem check beside it: rare cells whose
  raw rate sits above their band and those below, each must not lean. Also commit
  truth's per-cell dump (today a scratch worktree patch) so every analysis reads the
  same cells
- NL1 Measure the shape before fixing: residual by band (meio-model's shape.out has a
  first cut), and per band the spread of true rates with noise removed (method of
  moments) and its upper tail. Answers how much rare picks differ from each other and
  whether there are gems to protect
- NL2 Popularity bands for champion-roles: the prior mean per band, neighbours shrunk
  towards each other so thin bands borrow, no shape imposed; against the line and the
  -10 hinge. Simplest candidate for the off-role lean
- NL3 A spread per band: each band's own sd (MacKay, as the term kinds), and if NL1
  finds an upper tail, a two-part prior on the stable term a (as pair_mix tried on pair
  terms). If rare picks are a mixed bag, they are pulled less and gems surface sooner.
  Pass: the gem check, and the planted test below
- NL4 Keystones on two popularities: the keystone's share in the role (role-wide main
  term, Conqueror on a support) and on the champion-role (interaction), bands on each
- NL5 Popularity where the pick happens: log share in the cell's bracket and recent
  window against all patches and brackets (today's); keep the one with less lean
- NL6 Diamond+ popular overrated, Iron-Silver under: measure whether it holds on days
  8+ (data-rich) or only early; suspects the bracket term's single sd per role, and a
  bracket shift lagging across patches. Fix only once found
- NL7 Only if a lean remains after NL2-NL6: a correction table per kind x band x
  bracket from past patches' truth errors, shrunk, scored on the next patch. Visible on
  the method page; it patches over a cause, so last

The planted gem test (Jacob, 4 Nov: a rare pick that does well every patch but never
gets many games must stand out by the end), in meio.zig beside "a rare champion-role
shrinks to what rare picks win", a rare band at 46%, over 1, 3, 6 and 10 patches:

| planted pick | per patch | must |
| --- | --- | --- |
| gem | 40 games at 58%, every patch | above its band by patch N, range clear of it |
| fluke | 58% in one patch, 46% in the rest | not stand out |
| rare loser | 40 games at 36%, every patch | sink as far as the gem rises (no lean) |
| short gem | 58% in 2 patches only | stay mostly at the band |

N, the patches a gem needs, goes in Status. Today it fails twice: Meio sees ~30 days
(about 80 games of the gem), and its Gaussian prior on a (sd ~2 points) holds a
12-point gem at ~51% even at 400 games. Needs LH1-LH2 and NL3.

Later (needs player keys in the cubes): autofill as a player term (main role from the
player's recent games in the crawl), so a main-role player on a deliberate off-meta
pick is judged on the pick; cells carried by a few players discounted (per-cell phi).

## Long history (LH)

Jacob, 4 Nov: Meio takes far more than 30 days. A champion's lasting strength (the
stable term a) builds over every patch held; only the patch offsets d fade. Fading old
games as a whole would throw a gem's record away.

- LH1 Day cubes past 30 days: today keep_days in src/cubes.zig drops days before the
  views' first game (31 files on the box). Keep every day the database has (games since
  the crawl began; no backfill, J25) until LH2 says how many days Meio needs; that
  answer sets how many it keeps. ~115 MB a day,
  ~42 GB a year: small against the ~5.5 GB a day of raw data (research
  box-disk-headroom), but on the same disk. Views and the raw 30-days mode keep their
  own windows
- LH2 Meio over the whole history: more patch slots (today 3, older patches share the
  last) or the random walk (walk, M2) so each patch's offset leans on the one before;
  a step per patch estimated, larger at a season start or a big patch. Scored in truth
  at 30 days, 60, 90 and everything held, on the lean table, log loss and the gem test;
  the history Meio uses is where more stops helping, per kind if they differ (re-asked
  as patches pile up). The raw modes stay the baselines. Measure fit time and memory
  as history grows (truth: 5 GB on the Mac at 30 days; one run at a time), and that
  the box's daily refit stays within its limits
- LH3 The gem test on real data once enough patches are held: champion-roles rare in
  every patch with a raw rate above their band each time, Meio's middle tracked across
  origins

## Shifts learnt from trends (TS)

- TS0 Research (josearch, first): forecasting rate shifts after a balance patch from
  early signals: pooled shifts through shared features, lead-lag between segments,
  adoption and learning curves; sports, recommender and CTR drift, Dota. The store has
  training across patches (patch-shift-nets) but not this
- TS1 Shared movers: a champion-role's patch move = its own offset + sum over items and
  keystones of exposure x that option's move. Each option's move pooled over every
  champion using it, shrunk to 0 (one sd per kind); exposure from the previous patch.
  No change list. Checks: finds ranged Hubris on 16.21 unprompted (PT7: t -4.9);
  shuffled exposures gain 0. Scored on champion-role win rate, days 0-3
- TS2 Who leads: does Diamond+'s move on days 1-3 predict Gold-Emerald's and
  Iron-Silver's on days 4-10 beyond their own days 1-3; does KR's day (KR and VN2 patch
  a day before EUW) predict EUW1's day 0. Done 16.21: no lead, nor KR (model.md "Who
  leads a patch move")
- TS3 Behaviour first: pick-rate jumps and build shifts on days 0-1 (high volume) as
  predictors of win-rate moves on days 2-7
- TS4 Learning curve: after a champion-role's pick rate jumps, does its win rate rise
  with days since; if so, a small curve term. Done 16.21: no curve (same section)
- TS5 The winners of TS1-TS4 as the mean of Meio's patch offset d[cr, patch] (0 today),
  scored day by day; confirmed on 16.22

Not again: a share trend term (lost overall, model.md "Which side Meio misses on"); a
change list from Data Dragon (hid Hubris); nets for this (simple terms first).

## Order

NL0 first (every track reads its table and dump), with LH1 beside it (cubes take time
to build, and history only grows from when it starts being kept). Then NL1 and TS2
(measurements, cubes only) with TS0's research beside them, and the planted gem test.
NL2-NL5 next (meio-model's popularity work moves here), then LH2 and NL3 against the
gem test, then TS1. NL6, TS3-TS5 and NL7 after, each only if the earlier ones leave a
gap.

## Status

- Not started as a plan (4 Nov). Before it: meio-model scored the -10 hinge (variant A,
  model.md to come) and has the hinge in src/meio.zig, default off
