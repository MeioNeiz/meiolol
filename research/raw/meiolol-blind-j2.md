# docs/learned.md excerpts (commit 5b2ce85b)
- Before your lane opponent picks, ranking as if they were average is as good as any
  safer ranking we tried: favouring champions whose estimated matchups vary less is a
  hair better by one measure and a hair worse by another. Sure: 86k held-out games (29
  Oct snap), no enemy known: winners' picks rank a little higher (at most 7% of the
  ranking's link to winning; not seen on 57k dev games), winner-loser pairs are ordered
  slightly worse on dev and held-out games alike. The safer lists push popular champions
  down, so they partly measure popularity, not safety. Site: the app keeps its blind
  ranking; "safe blind" stays a label, not a different list. Evidence: docs/model.md
  "Blind pick ranking (J2)"
- Once the two champions' own win rates are allowed for, lane matchups still differ by
  about 2 points in top and mid, 1.2 in bot, 1.0 in support and 0.7 in jungle. Sure:
  method of moments on the live pages' tables (269k EUW games, 30 days). Site: the
  champion page's "vs usual" shrinks by usualK (about 750 games top and mid, the 2,500
  cap elsewhere); a 10% gap to a Python re-derivation is unexplained. Evidence:
  src/site/champion.zig usualK
- Who faces whom, and who plays beside whom, matters a little beyond each champion's
  strength. Lane matchups most: top 2.2-2.5 points between typical matchups, mid
  1.7-2.1, support 1.2-1.5, bot 1.1-1.3, jungle 1.0-1.4; mid vs enemy bot and bot vs
  enemy support 0.8-1.1. Among allies only bot and support show (1.3-1.6). A champion's
  own strength spreads 1.6-3.4 points by role. Sure: pre-declared, 134,375 held-out
  games of 2253Z, 1.24 ± 0.26 milli-nats over win-comp, 5 of 5 rounds; ranges run from
  the model's estimate to a simulation-calibrated one; single pairs not reported.
  Site: matchup and bot-lane synergy reasons on the draft board; no numbers for single
  pairs. Evidence: docs/model.md "Additive model v2: identified matchups"

# docs/model.md Blind pick ranking (J2)
### Blind pick ranking (J2), 2026-10-29 (w4)

Question (docs/plan/app.md APP3, J2): while my lane opponent is unknown, should the
pick list favour champions that hold up against the role's likely picks, rather than
rank as if the opponent were average (today: no lane term)? `meiolol eval --blind`
(src/blindpick.zig) on data/snap of 29 Oct (games 26 Sep to 29 Oct, every patch
pooled), the shipped model (as the stats file) fit on train, pick metric as Method but
with my lane opponent hidden. Variants add a per champion-role offset to the pick's
logit, over the role's likely opponents (10+ train games, weighted by them): the
expected lane term, its 25th and 10th percentile, mean minus one spread; and the base
rating's lower bound (minus one SE). Two scenarios: the other eight known; four allies
only. Gap = winners' mean percentile minus losers'; "vs today" is the paired difference
of gap or AUC, ± 95% by game (AUC by its DeLong placements). The gap is a mean of
percentiles, so a ranking that only moves the picked (mostly popular) champions up or
down the list changes it with the order among picks unchanged; AUC orders the picks
and reacts less. Top 10% win: picks in each ranking's own top 10%, so a different
number of picks per row, not paired.

Looks: variants pre-declared, dev-val first, nothing tuned. Test look 1 of data/snap
(29 Oct, w4) gave the gaps, AUCs and top 10%; look 2 (w4fix, same ranking code)
reproduced them to the last digit with the AUC intervals added: a reproduction for
paired output, as win-comp's rerun ("Comp features from champion profiles"), not a
second look at the question. Both are in data/snap's ledger (look 1 recorded after the
fact: `--blind` counted no looks then; it now needs `--test-look` on test), a rolling
copy that `deploy/box.sh snapshot` replaces, so this section is the record. Test: EUW1
ranked solo, every patch, from the cut 1792985933900 ms (2026-10-26 03:38:53.900 UTC:
the newest 15% of EUW1's played games, eval's own cut, not the all-platform protocol
one) to the copy's newest game, 1793301516647 ms (29 Oct 19:18:36 UTC): 85,904 games.
A later pin whose test window covers them lists them in its test-exclude.tsv. Copies
(gitignored): data/team/2026-10-29-next/w4/test-looks.tsv, and test-exclude.tsv there
(the 85,904 match ids, in that file's format). A further J2 test look runs on a pin.

Offsets (test fit, 809 champion-roles; dev within 0.002, r within 0.01):

| offset | mean | sd | r with log role games |
| --- | --- | --- | --- |
| expected lane term | -0.0002 | 0.0043 | 0.06 |
| 25th percentile | -0.0098 | 0.0103 | -0.58 |
| 10th percentile | -0.0205 | 0.0204 | -0.65 |
| mean minus spread | -0.0159 | 0.0154 | -0.66 |
| base rating minus one SE | -0.0996 | 0.0784 | 0.96 |

Dev-val (train 429k games to 24 Oct, 57k scored, 571k picks; today: gap 0.0190 / 0.0165,
AUC 0.5187 / 0.5168, top 10% win 51.90% / 51.62%):

| ranking | lane hidden: gap vs today | AUC vs today | top 10% win | no enemy: gap vs today | AUC vs today | top 10% win |
| --- | --- | --- | --- | --- | --- | --- |
| + expected lane term | -0.0001 ± 0.0001 | -0.0001 ± 0.0002 | 51.88% | +0.0000 ± 0.0001 | -0.0000 ± 0.0002 | 51.67% |
| + 25th percentile | +0.0002 ± 0.0003 | -0.0006 ± 0.0003 | 51.94% | +0.0003 ± 0.0003 | -0.0005 ± 0.0003 | 51.68% |
| + 10th percentile | -0.0002 ± 0.0005 | -0.0017 ± 0.0005 | 51.89% | +0.0002 ± 0.0006 | -0.0014 ± 0.0005 | 51.80% |
| + mean minus spread | +0.0001 ± 0.0004 | -0.0011 ± 0.0003 | 51.94% | +0.0004 ± 0.0004 | -0.0008 ± 0.0004 | 51.81% |
| base rating minus one SE | -0.0074 ± 0.0008 | +0.0006 ± 0.0004 | 51.81% | -0.0064 ± 0.0008 | +0.0001 ± 0.0004 | 51.55% |

Test (train 487k games to 26 Oct, 86k scored, 859k picks; today: gap 0.0191 / 0.0164,
AUC 0.5190 / 0.5169, top 10% win 52.09% / 51.81%):

| ranking | lane hidden: gap vs today | AUC vs today | top 10% win | no enemy: gap vs today | AUC vs today | top 10% win |
| --- | --- | --- | --- | --- | --- | --- |
| + expected lane term | +0.0001 ± 0.0001 | +0.0001 ± 0.0001 | 52.12% | +0.0001 ± 0.0001 | +0.0002 ± 0.0002 | 51.85% |
| + 25th percentile | +0.0002 ± 0.0002 | -0.0004 ± 0.0002 | 52.21% | +0.0004 ± 0.0002 | -0.0003 ± 0.0003 | 51.86% |
| + 10th percentile | +0.0002 ± 0.0004 | -0.0012 ± 0.0004 | 52.29% | +0.0006 ± 0.0005 | -0.0010 ± 0.0004 | 51.99% |
| + mean minus spread | +0.0003 ± 0.0003 | -0.0007 ± 0.0003 | 52.28% | +0.0005 ± 0.0003 | -0.0005 ± 0.0003 | 52.00% |
| base rating minus one SE | -0.0074 ± 0.0006 | +0.0004 ± 0.0003 | 51.79% | -0.0065 ± 0.0006 | -0.0001 ± 0.0003 | 51.53% |

Result: no ranking gains on every measure. On test, no enemy known, three gap intervals
exclude 0: 25th percentile +0.0004 ± 0.0002 (about 4 SE), 10th +0.0006 ± 0.0005 and mean
minus spread +0.0005 ± 0.0003, at most 7% of today's 0.0164 gap at the intervals' top;
their top 10% win is up 0.05 to 0.2 pp (unpaired, fewer picks). On test with the lane
hidden, the 25th percentile, mean minus spread and expected term's intervals end on 0
(+0.0002 ± 0.0002, +0.0003 ± 0.0003, +0.0001 ± 0.0001): at 4 decimals the table can't
say whether they exclude it. The low-end variants' AUC goes down, beyond its interval for
the 10th percentile and mean minus spread on both windows and scenarios and for the 25th
on three of four, and on dev no low-end variant's gap interval excludes 0. The base
rating's lower bound is the mirror case: gap clearly lower (-0.0074, 39% of it), AUC
level or slightly up (+0.0004 to +0.0006 with the lane hidden, both windows). Both
follow from the offsets: the low-end ones correlate -0.58 to -0.66 with log role games
and push popular champions down, the lower bound (0.96) pushes them up, and the gap
moves with that squeeze while AUC stays level or moves the other way. So the small gap
gain is as likely the squeeze as safety. The expected lane term is about 0 by
construction (sd 0.004): the fitted base rating already averages the champion over its
real opponents, so frequency-weighted lane deltas centre on 0; that it moves nothing is
a property of the model, not a finding about matchups. For a win or loss, the expected
win chance over the unknown opponent is the right target, and today's average-opponent
ranking already is it; "safe" only adds something under risk aversion a single game
doesn't have.

Not covered: the spread of shrunk estimates grows with the games behind each pair (thin
cells shrink to 0 or to their pair parents), so the quantile and spread variants mix in
data volume and may measure popularity or sample size rather than safety; a spread with
each pair's posterior variance taken out (score.termVar) wasn't tried. The likely
opponents' weights include the champions already picked and banned in that game, who
can't be the lane opponent (one offset per champion-role, not per seat). Pick order
isn't in the match data, so seats that were really counter-picked can't be split out;
an opponent that counters on purpose is the 10th percentile's case, and it doesn't help
on all seats.

