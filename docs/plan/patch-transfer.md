# Plan: training across patches, evaluated on the newest

Jacob, 21 Oct (16.21 out): train on more than the newest patch, learn how champions
change between patches, evaluate a model only on what it is used for (newest-patch
games). Jacob, 23 Oct: test only on the latest patch; train on as much of it as
possible while still evaluating on it; with 10M old-patch games the eval must not
leave the model trained only on old patches; a model that knows which old games are
less likely to differ on the new patch. Part of the data edge (J24,
docs/plan/estimates.md). Research: research/questions/patch-transfer.md (ratings level,
cited [pt C1]) and its child patch-shift-nets.md (nets, weighting, cited [psn C1]);
frontier-dynamics.md for drift in general. lab-frontier.md E2-E5 run here: E2 is A2,
E3 is A3 and PT7; E4 (mastery) and E5 (state-space) wait for PT4's result.

## The approach

1. Score the procedure, not one model. A procedure is a data recipe, a model and an
   update rule. Replay time day by day: the model as it stands at the start of day d
   (fit on everything before d, the new patch's earlier days included) scores day d's
   newest-patch games, then trains on them [psn C1, pt C6]. Every game was once a
   newest-patch game, so the whole history is test data without starving training: in
   the 10M case day 0 is scored by an all-old model, day 7 by one with six days of the
   new patch, exactly as the box would have served them
2. Each patch boundary is an episode: source = every game before it, target = the
   patch's days. Knobs are tuned on older episodes and reported on the newest, once.
   Mid-patch pseudo-boundaries are the null: a patch-aware arm must gain ~0 there
3. Split the model by what transfers. The stationary part (champion-role strength
   baseline, pairs, comp profiles, the net body) is fitted on every patch, so 10M old
   games still teach it. The patch part is small and shrunk: per-patch champion-role
   offsets or embedding deltas [pt C1, psn C5]. "Which old games to trust" becomes
   which old parameters to trust, per champion-role: a cell's old games inform the new
   patch unless the change list or the new patch's own games say it moved [psn C12,
   C15]. Per-game weighting or a domain classifier can't express that [psn C11]
4. Ship the same procedure: a daily warm-start update, a full refit per patch or week
   [psn C3]

Size of the prize: ignoring 16.21's jump cost ~1.1 milli-nats a game on day one, about
15% of the shipped model's edge over a coin, shrinking as the patch fills
(frontier-dynamics C11). The bigger win is honest numbers: every model claim measured
where it is used.

## Evaluation rule (protocol v3, for every arm here)

- Scored: games on the newest patch of their episode, by day since that patch went live
  on their platform (first game seen on it there; KR and VN2 a day ahead of EUW), in
  buckets 0, 1, 2-3, 4-7, 8+, plus the patch-lifetime mean (each day weighted equally:
  the site serves every day of a patch)
- Fit for day d: every played game starting before day d's first scored game, any
  platform, any patch (the shared protocol's leak note holds: one time cut)
- Paired per-game differences, intervals as usual; also the slice of games with a
  changed champion, where the gains should sit. Noise: sd ~0.022 nats per game, so
  16.21's 252k games by 23 Oct give about ± 0.09 milli-nats
- Tuning: on older episodes. Until a third episode exists, tune on 16.21's days 0-3 and
  score days 4+ [pt C7]; from 16.22 (due about two weeks after 21 Oct) 16.21 becomes a
  dev episode and 16.22 the sealed one
- Nets: seeds and sealed seeds as in docs/model.md "Nets on the shipped model"

## Steps

- PT0 Jacob's choices: (a) backfill older patches for more episodes (16.17-16.18 via
  match-v5 history; Riot budget, likely after the production key); (b) protocol v3 as
  the rule for every model claim, the daily box eval included (PT8). Blocks PT7 (a)
  and PT8 (b)
- PT1 Episode pin. Drafts for every patch (drafts table, 74 bytes a game: 10M games is
  740 MB) plus per game game_start ms, platform, patch, day since patch on that
  platform; seat stats for the set net's profiles (from the raw archive, 3091e18).
  Side tables per patch: Data Dragon champion and item diffs (changed flags, signed
  numeric diffs), item exposure per champion-role (share of its old-patch seats that
  finished each changed item), the old patch's deviation per champion-role (mean
  reversion, frontier-dynamics C5). Done when: a pin covering 16.20 and 16.21 days 0-3+
  is on the gpu-box and the Mac, with split.tsv-style cut lines per day. Start:
  deploy/snapshot.sh, protocol.zig writeSplit. Blocks PT2-PT6
- PT2 Prequential harness. A day-loop mode in exp/win-context and netcheck: for each
  day d, fit (or update) on games before d, score day d's newest-patch games, write
  per-game preds by day bucket; arms paired on the same games. Done when the shipped
  model (additive v2) has its 16.21 curve by day and a pseudo-boundary inside 16.20
  gives ~0 for a patch-offset arm. Start: src/lab/harness.zig cuts, eval.zig --patch,
  netcheck --window. Blocks PT4-PT6
- PT3 What transfers (measurement, no model). Per block (champion-role main effect, ally
  pairs, matchups, comp profile terms, the profile features themselves) the cross-patch
  agreement over the within-patch split-half reliability, by changed, item-exposed and
  untouched champions, by day since patch. A ratio near 1 means pool it, well below 1
  means it needs a patch part. Also Step 0's jump table rerun by day for 16.21's first
  week. Done when: a table in model.md and a learned.md line. Can run on PT1 before PT2
- PT4 Ratings arms on additive v2 (CPU, cheap; picks the base for the nets). Table
  below. Done when: each arm's curve by day bucket vs A1 with intervals, and one winner
  or "pool wins"
- PT5 Net arms on the PT4 winner (gpu-box). Table below. Done when as PT4, with sealed
  seeds and the control
- PT6 Train-vs-eval allocation curve (below), for knobs tuned on new-patch games only
- PT7 Shift predictor (A6): regress per-champion-role jumps on the PT1 side tables over
  3+ episodes; its prediction becomes the offset's prior mean. Needs PT0 (a) or two more
  live patches. Patch-note text is lab-frontier W4
- PT8 Ship: the winning procedure runs on the box (daily update, refit per patch); the
  daily eval (deploy/web-loop.sh, data/eval-history.tsv) switches to protocol v3; the
  site's stats and the draft export follow the winning data rule (today: newest patch
  for `meiolol stats`, every patch for the draft export)

## Ratings arms (PT4)

All on additive v2's rows and terms; the patch part is per champion-role.

| arm | fit | what it tests |
| --- | --- | --- |
| A0 newest only | newest-patch games only | the "train on the newest patch" baseline |
| A1 pooled | every game, no patch term | the bar [pt C2] |
| A2 pooled + offsets | rating + o[c][patch], one L2 | Daumé AUGMENT [pt C1] |
| A3 changed-aware | A2, looser L2 for changed or item-exposed champions | does the change list help days 0-1 [pt C8] |
| A4 warm start | last patch's fit as prior mean, L2 toward it, newest only | Chelba-Acero [pt C1] |
| A5 recency | pooled, old-patch games weighted w | decay; expected to lose [dynamics C2] |
| A7 target up-weight | pooled, newest-patch games x a (2-20) | the weighting any pruning must beat [psn C13] |
| A8 spike and slab | A2, o's prior a mixture: tight unless the change list or the new games say moved; P(moved) per champion-role | Jacob's "which old games to trust", learnt from the change list and the new patch |
| A9 per-cell weights | A1 with a champion-role's old games down-weighted in its own terms only when changed | weighting done right [psn C15]; vs A3 |
| G game weights | A1, each old game weighted by the product over its ten champion-roles of a trust r | model-agnostic, usable by any net; expected to lose to A9 [psn C14] |
| C shuffled | A2 with patch slots hashed | control: must gain nothing |

A6 (learned delta) is PT7. Domain-classifier weighting is ruled out [psn C11].

## Net arms (PT5)

On the set net + champion-role embedding, residual on the PT4 winner's logit.

| arm | procedure | what it tests |
| --- | --- | --- |
| N0 pooled net | today's recipe, fresh fit on every game, base patch-aware | does the base absorb the patch, net pooled [psn C5] |
| N1 embedding deltas | e[c] + d[c][patch], L2, looser for changed; deltas fitted first, body frozen, then all | the A2/A3 structure in the net [psn C8] |
| N2 daily update | warm start, one pass on day d-1; all weights / embeddings only / head only; replay 0, 5, 25%; learning rate re-raised | IncCTR vs surgical [psn C3, C4, C7] |
| N3 per-patch refit | pooled refit at each patch: fresh / warm / shrink and perturb (0.3-0.6) | warm-start penalty [psn C6] |
| N4 reference | fresh full refit before each of days 0, 1, 3, 7 | what N2 should match |
| C pseudo-boundary | N1 and N2 at a fake boundary mid-16.20 | control: must gain ~0 |

A new champion's embedding starts at its role's mean [psn C16]. Expected: N2 with
embeddings only wins days 0-3, the gap to N2 all weights closing by day 7 [psn C4].

## The train-vs-eval allocation curve (PT6)

Only for a knob tuned on new-patch games (A3's looser L2, A7's a, N2's learning
rate); the procedure itself needs no split (approach 1). For each n in {2k, 5k, 10k,
25k, 50k, 100k} earliest new-patch games and k/n in {0, 0.25, 0.5, 0.75}: tune on the
first k, score (a) the rest of the n and (b) a fixed later block (the truth). Report the
gain over A1 on (b) and how far (a) is from (b) over 20 repeated splits by day. The
answer is the k where (b) stops improving and the n where (a) stops being noise.

## Boundaries we can replay

- 16.20 to 16.21: the real one. 1.32M 16.20 games; 16.21 252k by 23 Oct (EUW1 53k, KR
  67k, VN2 46k, NA1 20k), ~100k a day
- 16.19 to 16.20: weak, 17k 16.19 games left in drafts (54,750 in the 2253Z snapshot)
- Each new patch adds one; backfill is PT0 (a)

## Status

- Step 0 done 21 Oct: 16.21's first day moved champion-role win rates 0.75 pp RMS
  within platform vs 0 for a within-patch control, 1.9 pp for the 12 champions with
  Data Dragon changes vs 0.5 pp for the rest (docs/model.md "Patch 16.21's first day")
- The 13 Oct per-patch offsets test found nothing, but every scored game sat on a patch
  the fit already held (16.20). Every net result so far (to 1320Z) was scored on 16.20
  games only: valid within a patch, silent on boundaries
- Exists: `meiolol eval --patch P` (trained on the test patch only vs every patch),
  win-context's rating + o[c][patch] with one L2 and cfg.shuffle, netcheck --window.
  Missing: everything in PT1-PT2

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
