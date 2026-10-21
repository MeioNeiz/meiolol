# Plan: training across patches, evaluated on the newest

Jacob, 21 Oct (16.21 out): train on more than the newest patch and get as much as we can
from the previous one; learn how champions change between patches so a new patch is
learnt faster; evaluate a model only on what it is used for (newest-patch games); with
few new games, maybe spend them on evaluation rather than training. Research:
research/questions/patch-transfer.md (and frontier-dynamics). Replaces nothing in
lab-frontier.md: this is E2-E5 made concrete.

## What we know (21 Oct)

- 16.21's first day moved champion win rates 0.75 pp per pick (RMS, within platform),
  while two later days of 16.20 moved 0.00 vs the week before. Champions with Data
  Dragon changes moved ~4x the rest (1.9 vs 0.5 pp). Ignoring the jump costs ~1.1
  milli-nats per game on day one, ~15% of the shipped model's edge over a coin
  (docs/model.md "Patch 16.21's first day")
- The 13 Oct test (16.19 to 16.20, per-patch offsets) found nothing, but it never scored
  a patch's first days: every scored game sat on a patch the fit already held plenty of
- Literature: pooling all past data is the bar that adaptation methods rarely beat
  [patch-transfer C2]; the two that do are "shared plus per-domain copy" (our
  stationary rating plus per-patch offset) and "fit the new domain with an L2 prior
  centred on the old model" (warm start), and both lose when target data is too thin
  to tell domains apart [C1, C3]. That is day one of a patch, unless the prior knows
  which champions changed [C5]

## Evaluation rule (adopted for these experiments)

- Score only newest-patch games, grouped by day since the patch went live on that
  platform (day 0, 1, 2-3, 4-7, 8+), plus their pick-weighted mean
- Rolling origin (Wild-Time's Eval-Stream, test-then-train): for each day d of the new
  patch, fit on everything before day d, score day d, move on. Every new game is first
  a test game, then a training game, so there is no train-vs-eval trade-off for the
  procedure we ship (refit as games arrive) [C6]
- The trade-off only exists for a knob tuned on new-patch games (a shrinkage strength).
  For one or two knobs, where the line falls barely matters [C7]; tune on the earlier
  days, score the later ones
- Paired per-game differences, clustered by game, intervals as usual. Noise: sd ~0.022
  nats per game for close models, so 50k new games give ± 0.19 milli-nats

## Boundaries we can replay

- 16.20 to 16.21: the real one. Source 1.32M 16.20 games; target grows ~50k games a day
  (more once the crawler fix of 21 Oct finds new-patch players faster)
- 16.19 to 16.20: weak, only 54,750 16.19 games (crawl began late in 16.19); usable as
  a second boundary with a small source
- Older patches: match-v5 keeps ~2 years of ids per player, so a deliberate backfill of
  16.17-16.18 games would give more boundaries (costs Riot budget; Jacob's call, after
  the production key)

## Arms (all on the same rows and model family: win-context's ratings)

| arm | fit | what it tests |
| --- | --- | --- |
| A0 newest only | 16.21 games only | the "train on the newest patch" baseline |
| A1 pooled | every game, no patch term | the bar (Wild-Time: hard to beat) |
| A2 pooled + offsets | rating + o[c][patch], one L2 | Daumé AUGMENT; win-context +patch today |
| A3 changed-aware offsets | as A2, looser L2 for changed champions | does knowing the patch's list help day 0-1 |
| A4 warm start | 16.20 ratings as the prior mean, L2 toward them, fit 16.21 only | Chelba-Acero PRIOR |
| A5 recency weight | pooled, old-patch games weighted w (tuned) | Daumé WEIGHTED |
| A6 learned delta | A3 with the offset's prior mean from a regression of past jumps on Data Dragon diffs and old deviation | Jacob's "learn the changes" |
| C shuffled | A2 with patch slots hashed | control: must gain nothing |

A6 needs several boundaries to fit the delta regression: with two it can only be a
shape test (does the sign of a cooldown or stat change predict the sign of the jump),
not a fit. Patch-note text is frontier-pretrain's W4.

## The train-vs-eval allocation curve

Jacob's question: with n new games, is it better to train on k and evaluate on n-k, or
evaluate on more? For each n in {2k, 5k, 10k, 25k, 50k, 100k} new-patch games (the
earliest n by time) and k/n in {0, 0.25, 0.5, 0.75}: fit A2-A4 with the first k as
new-patch training, score (a) the rest of the n games and (b) a fixed later held-out
block (the truth). Report per cell the gain over A1 on (b), and how far (a) differs from
(b) across 20 repeated splits by day. The answer is the k where (b) stops improving and
the n where (a) stops being noise. Expected from Step 0: the fit gains little from k
below ~10k unless A3's prior is in play, and (a) is usable from ~5k games.

## Steps

- Step 0 (done 21 Oct, no model): patch jump size by champion from the drafts table,
  SQL below. Rerun daily for the first week of 16.21 to see the jump by day since patch
- Step 1: a snapshot with 16.21 (lab-frontier P1; the newest pin is 18 Oct). Needs the
  gpu-box or a Mac copy of the box DB; P1's other fields are not needed for this plan,
  so a drafts-only pin (the drafts table, 74 bytes a game) is enough for A0-A6
- Step 2: win-context gains day-since-patch scoring and a rolling-origin mode (fit up
  to day d, score day d), the newest-patch-only filter for scoring, the changed list
  (A3, from the Data Dragon diff) and a prior-mean input (A4, A6)
- Step 3: run A0-A5 + C on 16.20 to 16.21 by day since patch; then the allocation curve
- Step 4: A6 only if A3 beats A2 on days 0-1 and a second boundary is available
- What ships if an arm wins: the site's stats and the draft model are built from the
  newest patch's games today (`meiolol stats` default) or every patch (draft export);
  the winner replaces that rule

## What exists and what is missing

- `meiolol eval --patch P` (src/eval.zig): restricts the games to patches; its report
  already has "trained on the test games' patch only" vs "trained on every patch" (the
  11 Oct baseline found no difference, 481 games). No day-since-patch, no rolling origin
- `meiolol-lab exp run SNAP CAMPAIGN win` with src/lab/cand/win-context: rating +
  o[c][patch] with one L2, cfg.shuffle control, 5 forward folds. Missing: per-champion
  L2 (A3), prior mean (A4, A6), scoring by day since patch, newest-only scoring
- Snapshot: none has 16.21 yet. Drafts table on the box has every game since 26 Sep

## Step 0 SQL

Export on the box (read-only, ~20 s, ~27 MB gzipped):

```
sqlite3 -readonly -separator "	" meiolol.db "SELECT platform, queue, patch, day,
  blue_win, hex(picks) FROM drafts WHERE patch IN ('16.20','16.21')" | gzip -1 > f.gz
```

Locally, import into table d, then one row per pick (picks: 10 x u16 LE, champion =
v & 8191, role = (v >> 13) - 1, slots 0-4 blue):

```
CREATE TABLE s (i INT); INSERT INTO s VALUES (0),(1),(2),(3),(4),(5),(6),(7),(8),(9);
CREATE TABLE p AS WITH x AS (SELECT d.patch, d.day, d.platform,
  CASE WHEN s.i < 5 THEN d.blue_win ELSE 1 - d.blue_win END AS win,
  substr(d.picks, s.i*4+1, 4) AS h FROM d JOIN s WHERE d.queue = 420),
v AS (SELECT patch, day, platform, win,
  ((instr('0123456789ABCDEF', substr(h,3,1))-1)*16
    + instr('0123456789ABCDEF', substr(h,4,1))-1)*256
  + (instr('0123456789ABCDEF', substr(h,1,1))-1)*16
    + instr('0123456789ABCDEF', substr(h,2,1))-1 AS val FROM x)
SELECT patch, day, platform, win, val & 8191 AS champ, (val >> 13) - 1 AS role FROM v;
```

Then per (platform, champion, role) picks and wins in the old window, the new patch and
the control window; tau^2 = pick-weighted mean of (d^2 - p(1-p)(1/n_old + 1/n_new)).
Changed list: championFull.json of both versions, champions whose stats or spells
(cooldown, cost, range, effectBurn, tooltip) or passive text differ.
