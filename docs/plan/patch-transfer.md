# Plan: the latest patch, with old patches while it is thin

Jacob, 23 Oct: we mostly analyse the latest patch and keep it simple. The model is
evaluated against latest-patch games only; old patches are used only to adjust the
model while the latest patch has too few games to train and evaluate on its own (J25).
Research: research/questions/patch-transfer.md (ratings level, cited [pt C1]) and its
child patch-shift-nets.md (nets, cited [psn C1]). lab-frontier.md E2-E3 run here (A2,
A3); E4-E5 only if PT3 finds a jump worth modelling.

## The approach

1. Score only latest-patch games, day by day since the patch: the model as it stands
   at the start of day d (fit on everything before d) scores day d's games, then trains
   on them [psn C1, pt C6]. Every latest-patch game is a test game once and a training
   game after, so a thin patch is no train-vs-eval trade-off: day 0 is scored by a
   model leaning on the old patch, day 7 by one with six days of the new
2. The model: a stable part fitted on every game plus a small per-patch champion-role
   offset, shrunk to 0, looser for champions the patch changed [pt C1, C8, psn C5]. The
   offset takes over as the patch fills
3. The answer we want is simple: from which day (or how many latest-patch games) old
   patches stop helping. Before that, use the winning arm; after it, latest patch only

Size: ignoring 16.21's jump cost ~1.1 milli-nats a game on day one, about 15% of the
shipped model's edge over a coin, shrinking as the patch fills (frontier-dynamics C11).

## Evaluation rule

- Scored: latest-patch games, by day since the patch went live on their platform
  (first game seen on it there; KR and VN2 go a day ahead of EUW), in buckets 0, 1,
  2-3, 4-7, 8+, plus the mean over the patch (days weighted equally)
- Fit for day d: every played game starting before day d's first scored game, any
  platform, any patch (one time cut, as the shared protocol's leak note)
- Paired per-game differences, intervals as usual; also the games with a changed
  champion. Noise: sd ~0.022 nats a game, so 16.21's 252k games give ± 0.09 milli-nats
- Tuning (a shrinkage strength): on 16.21's days 0-3, scored on days 4+ [pt C7]; from
  16.22, tuned on 16.21 and scored on 16.22

## Steps

- PT1 Pin with 16.21: drafts for 16.20 and 16.21 (drafts table, 74 bytes a game), per
  game start ms, platform, patch, day since patch on that platform; seat stats for the
  set net's profiles (raw archive, 3091e18); the changed list from the Data Dragon
  diff (Step 0 below). Done when it is on the gpu-box and the Mac. Start:
  deploy/snapshot.sh, protocol.zig writeSplit. Blocks PT2-PT4
- PT2 Day-by-day mode in exp/win-context and netcheck: fit (or update) before day d,
  score day d's latest-patch games, per-game preds by day bucket. Done when additive
  v2 has its 16.21 curve by day and a shuffled-patch control gains ~0. Start:
  src/lab/harness.zig cuts, eval.zig --patch, netcheck --window
- PT3 Ratings arms (CPU), on additive v2's terms. Done when each arm has its curve by
  day vs A1 and the day where A0 catches up is known

  | arm | fit | tests |
  | --- | --- | --- |
  | A0 latest only | latest-patch games only | where old patches stop helping |
  | A1 pooled | every game, no patch term | the bar [pt C2] |
  | A2 pooled + offsets | rating + o[c][patch], one L2 | the main candidate [pt C1] |
  | A3 changed-aware | A2, looser L2 for changed champions | does the change list help days 0-1 |
  | A4 warm start | last patch's fit as prior mean, latest only | the other candidate [pt C1] |
  | A7 latest up-weight | pooled, latest-patch games x a (2-20) | simplest weighting [psn C13] |
  | C shuffled | A2 with patch slots hashed | control: must gain nothing |

- PT4 Net (gpu-box): the set net + embedding on PT3's winner as its base; fresh pooled
  fit vs a daily warm-start update (embeddings only vs all weights, 5% old games mixed
  in) [psn C3, C4, C7]. Done as PT3, with sealed seeds
- PT5 Ship: the winning rule on the box (daily update, refit per patch); the daily eval
  (deploy/web-loop.sh, data/eval-history.tsv) scores latest-patch games only

## Later (only if PT3 shows a real jump the simple arms miss)

- Which old champion-role data to trust, learnt: a spike-and-slab prior on the offsets
  [psn C15]; never per-game weights or a domain classifier [psn C11]
- Predicting a champion's jump from what the patch changed (needs 3+ patches: 16.22,
  16.23; no backfill, J25)
- Per-block transfer (pairs, matchups, comp terms across patches); the train-vs-eval
  allocation curve for tuned knobs

## Status

- Step 0 done 21 Oct: 16.21's first day moved champion-role win rates 0.75 pp RMS
  within platform vs 0 for a within-patch control, 1.9 pp for the 12 champions with
  Data Dragon changes vs 0.5 pp for the rest (docs/model.md "Patch 16.21's first day")
- Every net result so far (to 1320Z) was scored on 16.20 games only: valid within a
  patch, silent on what happens at one
- 16.21: 252k games by 23 Oct (EUW1 53k, KR 67k, VN2 46k, NA1 20k), ~100k a day

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
