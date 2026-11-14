# Plan: the latest patch, with old patches corrected for it

We mostly analyse the latest patch and keep it simple: the model is evaluated against
latest-patch games only (J25). Old patches always stay in, with a correction between
patches, never latest patch only (J28).
Research: research/questions/patch-transfer.md (ratings level, cited [pt C1]) and its
child patch-shift-nets.md (nets, cited [psn C1]) and early-patch-forecast.md (what others
do in a patch's first days, cited [epf C1]). lab-frontier.md E2-E3 run here (A2,
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
3. The answer we want: which correction wins on every day bucket, and how it should
   loosen as the patch fills (J28: pooled always; A0 stays as a reference arm only)

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
  | A0 latest only | latest-patch games only | reference only (J28) |
  | A1 pooled | every game, no patch term | the bar [pt C2] |
  | A2 pooled + offsets | rating + o[c][patch], one L2 | the main candidate [pt C1] |
  | A3 changed-aware | A2, looser L2 for changed champions | does the change list help days 0-1 |
  | A4 warm start | last patch's fit as prior mean, latest only | the other candidate [pt C1] |
  | A7 latest up-weight | pooled, latest-patch games x a (2-20) | simplest weighting [psn C13] |
  | C shuffled | A2 with patch slots hashed | control: must gain nothing |

- PT4 Net (gpu-box): the set net + embedding on PT3's winner as its base; fresh pooled
  fit vs a daily warm-start update (embeddings only vs all weights, 5% old games mixed
  in) [psn C3, C4, C7]. Done as PT3, with sealed seeds
- PT6 EUW as the target region (J27). Scored set: EUW1 latest-patch games decide,
  every other platform reported beside (KR, VN2, rest); fit still on every platform,
  as every region's games beat EUW's alone (learned.md). Arms on PT3's winner:
  A8 region offsets o[c][r][region] shrunk to 0, A9 EUW up-weight (EUW1 games x a,
  2-10), and knobs tuned on EUW vs on every region. Noise: EUW1 is ~21% of 16.21 (53k
  games), so ± ~0.19 milli-nats against 0.09 for all. Done when each arm has its EUW
  curve by day vs A1, and lab-frontier.md's pass rule says EUW1 decides (today per
  platform is reported, never deciding). Start: patchdays.zig (platform per game is in
  the pin). Blocked by PT1
- PT9 A second patch: replay 16.22's days 0-3 as PT3 did 16.21 (A0, A1, A2, C) on a new
  pin once 16.22 has ~7 days, then its own declared test look. With 16.21's look, two
  patches decide PT5, not one
- PT10 Arms from prior art, for a declared look on 16.23. Nobody found scores a forecast
  of patch moves out of sample, and the big stat sites reset or show an unweighted
  window [epf C1, C10], so each arm is a test, not a port. Knobs fitted on 16.21 and
  16.22, scored on 16.23's days 0-3 by day bucket against A2 (patchdays) and Meio's
  champion-role kind (truth); rule and numbers declared before 16.23's first game

  | arm | what | fitted | why |
  | --- | --- | --- | --- |
  | S1 signed mean | A2, offset mean = sign x m for champions the notes change directly; label (buff, nerf; adjustments 0) coded from Riot's notes before any game | m per sign | the one arm that can beat A1 on day 0; sign codes 87-99% reliably, one in-sample backtest cut error 16% [epf C9, C10]; buffs miss more than nerfs [epf C11] |
  | S2 pad by forecast error | per kind, the pad X = 4 / sd^2 games that best predicts the next 7 days from every origin | X per kind | the fitted pad came out a third of the formula's in sport [epf C5]; ours is 7-10k games a champion-role [epf C13]. A check on MacKay's sd: kept only if X differs over 2x and wins |
  | S3 micropatch boundary | a champion Riot changes mid-patch gets a new offset slot from that day | none | day 0 of a hotfixed champion is another champion [epf C14]; only if 16.23 has one |
  | S4 reversion | S1's champions, mean = -b x last patch's distance from the role's middle | b | misses are corrected next patch [epf C8]; a hint on 16.21's 12 changed; beside S1 only |

  Size: changed champions carry about half of day 0's ~1.1 milli-nats, so S1 can gain
  ~0.1-0.2 at most, on day 0 and day 1; m and b come from ~25 changed champions over two
  boundaries. Not arms: sizes from the notes before S1 passes, designer sizes (none
  published), means for unchanged champions, a changed-champion variance (A3) [epf C8,
  C9, C11, C12]. Beside: LoLalytics, U.GG and OP.GG defaults saved on 16.23's days 0-1
- PT5 Ship: the winning rule on the box (daily update, refit per patch); the daily eval
  (deploy/web-loop.sh, data/eval-history.tsv) scores latest-patch games only
- PT7 Patches as experiments (Jacob, 4 Nov; Meio M8 in estimates.md): patchnotes.zig's
  change list as interventions. Does a champion's move across 16.21 -> 16.22 track its
  prior exposure to a changed item or rune (unchanged ones the null, build mix fixed)?
  If so, Meio's patch prior widens by exposure, not only for champions named in the
  notes (A3), and interactions add up patch by patch. Few patches held (J25), small moves
- PT8 Shifts learnt from trends, no change list (Jacob, 4 Nov): shared movers through
  items and keystones, who leads (ranks, KR before EUW), behaviour before win rates,
  learning curves. Steps TS0-TS5 in meio-middle.md

## Later (only if PT3 shows a real jump the simple arms miss)

- Which old champion-role data to trust, learnt: a spike-and-slab prior on the offsets
  [psn C15]; never per-game weights or a domain classifier [psn C11]
- A model per region for each region's pages, once A8 shows region terms help EUW
- Per-block transfer (pairs, matchups, comp terms across patches); the train-vs-eval
  allocation curve for tuned knobs

## Status

- PT7 first look (16.20 -> 16.21, docs/model.md "Patches as experiments"): the ranged
  Hubris nerf moved ranged champion-roles that build it (-0.029 +- 0.009 logit at full
  exposure, ~4 null sds); Bastionbreaker not sure, melee Hubris tangled with it. Data
  Dragon missed the Hubris change: exposure needs Riot's notes. 16.22 at its day 7
- Step 0: 16.21's first day moved champion-role win rates 0.75 pp RMS
  within platform vs 0 for a within-patch control, 1.9 pp for the 12 champions with
  Data Dragon changes vs 0.5 pp for the rest (docs/model.md "Patch 16.21's first day")
- Every net result so far (to 1320Z) was scored on 16.20 games only: valid within a
  patch, silent on what happens at one
- 16.21: ~120-135k games played a day (drafts table)
- PT2-PT3 tool: `meiolol-lab patchdays`; dry run with 16.20 as latest (docs/model.md "The latest patch day by day"): control gains 0, pooled wins,
  no jump detectable as 16.19 has only 51k games
- PT1 pinned: snap-20261029T1810Z (28 Oct 04:00 backup, games to 28 Oct 03:43Z), cut
  24 Oct 23:16Z, ~6 h before EUW1's day 4: days 0-3 dev, the rest test. On the
  gpu-box (~/ml/snaps); not yet on the Mac
- PT3 on 16.21, dev (docs/model.md "The latest patch day by day on 16.21"): pooled +
  offsets (A2, sd estimated) wins, -0.28 ± 0.07 milli-nats a game vs A1 on days 1-3
  (EUW1 -0.31 ± 0.16), control 0; the changed list adds nothing once the sd is
  estimated (A3 - A2 -0.02 ± 0.03); A0 is still +2 behind on day 3; A4 and A7 lose.
  Test look on days 4+ declared, not run (Jacob's call; docs/model.md, same section):
  A2 estimated minus A1 on the test games of days 4+, all platforms, passes when d + h
  < 0; EUW1 and the test minus test-exclude.tsv (J2's EUW1 games) beside. Then PT4 and
  PT6 on A2

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
