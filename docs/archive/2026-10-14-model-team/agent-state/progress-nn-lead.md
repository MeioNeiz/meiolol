# Progress: lead NN modeller (meiolol-04 [79f90e]; NOT meiolol-04 [904e99] = lab tooling; from meiolol-0a [101155], from meiolol-f1)

Owns src/lab/winnet.zig (netcheck; free, no other editor now), src/lab/draftnet.zig, src/gpu/draftnet_layout.zig + dn_* kernels. Scratchpad:
/private/tmp/claude-501/-Users-jacobmaschler-personal-meiolol/a9f86699-422c-41e2-abb7-71bd99113782/scratchpad
(summ.py DIR... = ens vs cand, pair.py A B = B's ens minus A's, paired by game).
All runs on the gpu-box now (Jacob, 13 Oct 22:40); f1's old runs in data/netcheck/f1 (Mac).

## Commits (13 Oct, not pushed)
- 9ace58d big --evals N (sub-epoch early stopping), refit in steps; seed-3=seed-1 fix
- 0696aad netcheck writes DIR/games-<cand>.tsv, games-<net>.tsv (gains' shape); 35's set hook
- f996ce0 draftnet residual: dn.Game.off x learnt a, Config.resid (output weights 0)
- f29a170 --shuffle-ids SEED (4b's control) + winnet.healthFit (tests session 0a [01815a])
- 521c004 netcheck --net bigres (big as residual on cross-fitted offset); winnet.zig back with me after 08's c2ec378 (--fit-preds 1)
- fd47860 model.md + nets.tsv: bigres on win-comp and control, t23 vs win-comp
- 9ed8df9 learned.md line (audited by 4b); 6eb74a8 nets.tsv leads with sealed seeds 11-20 (bd)
- 1934a30 model.md "Big net: tuning, seed ensembles, confirmation (meiolol-0a)" + nets.tsv rows (verdict: big ens level, leaning slightly better, noise floor)

## Runs
| id | question | status | result (log loss vs cand, negative better, folds pooled) |
| --- | --- | --- | --- |
| e1/e4 (Mac scratch) | big: val checks 1 vs 4 per epoch | done | e4 - e1 +0.00031 ± 0.00026 (worse); same 1-2 epochs; dropped from sweep |
| 0a-pscr / 0a-pinit (Mac) | small emb 12 scratch vs 52's d12 init | done | scratch +0.00022 ± 0.00025 (2/5 folds better), init -0.00004 ± 0.00054 (3/5); init - scratch -0.00026 ± 0.00057 |
| 0a-pfrz (gpu-box cpu) | small, d12 init frozen | done | +0.00049 ± 0.00068 (worse, n.d.); no d12 form helps |
| 0a-dnagree (gpu-box gpu) | f996ce0 kernel: CPU and GPU agree (draftbench --limit 20000) | done | 40 steps: max diff 9.8e-4, same as compute.md's 1e-3 baseline; test loss equal |
| 0a-big-def10 (gpu-box gpu) | default big, 10 seeds vs ratings | done | -0.00039 ± 0.00033 (4/5 folds), dev -0.00006 ± 0.00070; single seeds +0.0006..+0.0019; ens 1/3/5/10: +0.00116/-0.00011/-0.00019/-0.00039; dev: 2-epoch seeds ~+0.003 worse than 1-epoch |
| 0a-big-def10-rs1 (gpu-box gpu) | confirmation: default 10 seeds on a 90% resample | done | -0.00010 ± 0.00035, 2/5 folds; reading: big ens level, leaning slightly better (~0.1-0.3 mnats), at the noise floor |
| 0a-big-def-s11-20 (gpu-box gpu) | sealed confirmation, seeds 11-20 | done | alone -0.00012 ± 0.00036; 20 seeds -0.00034 ± 0.00032 (upper -0.00002), 4/5 folds: confirmed by the letter, marginal; awaits rs1 |
| big1b (1c's sweep) | big lr/wd/batch/patience, 5 seeds, rank on val | done | data/sweeps/big1b/table.md; all 32 worse per seed (-1.0..-3.2 mnats gain), ens -0.6..+0.2; top-12 val within 0.0002; pick t23 (lr 0.002159 wd 0.0002976 batch 256 patience 3); big1 t01-t08 (8 trials) left out |
| 0a-t23-10-win-ratings / -win-comp (gpu-box gpu) | t23, 10 seeds, vs ratings and vs win-comp | done | vs ratings -0.00009 ± 0.00046 (3/5) = level; vs default-10 +0.00031 ± 0.00038; vs win-comp +0.00033 ± 0.00055 (n.d., worse) |
| 0a-bigres-smoke (gpu-box gpu) | bigres runs, vs win-comp, 1 seed, block 1 | done | works: offset weight 0.946, val 0.69029 -> 0.69014; fold 1 +0.00036 ± 0.00062 (plumbing only) |
| big1c (meiolol-fd's sweep, design A) | slow big: lr 3e-5..3e-4, batch 1024-4096, patience 2|3; 24 x 3 seeds; default as reference row | asked fd to queue | top 3 by val -> my 10-seed check; B (fixed-budget flag) held |
| teacher (planned, meiolol-08) | winner (big ens; bigres too if run) with --fit-preds 1 (c2ec378), all blocks, same seeds, ~6x cost | after winner-10 | send run dir to 08 |
| 0a-bigres-t23-wc + -shuf (gpu-box gpu) | t23 bigres on win-comp, 10 seeds, + --shuffle-ids 1 control | done (fd47860) | bigres -0.00034 ± 0.00035 vs win-comp (3/5, n.d.), offset w median 0.837; control +0.00042 ± 0.00034 (1-epoch noise floor, no leak), median 0.882; real - control -0.00076 ± 0.00046; sent to 4b |
| rb-ref-wr (2253Z, 21412d3) | VOID (pre-re-cut) | void | - |
| rb-ref-wr re-cut 002905Z (0c3e486) | ratings, small 1-5, resid 1-5 | done, sent 14 | folds 134,375, dev 35,834; ratings 0.68901 / 0.68780, acc 53.71 / 53.75%, abs(p-.5) 0.0374; small ens -0.34 ± 0.14 (5/5), seeds +0.08 sd 0.20, acc +0.04 pp, dev -0.67 ± 0.33; resid -0.17 ± 0.08 (4/5), w median 0.95, dev +0.03; awaits new floor |
| rb-big-wr 003419Z + s11 003523Z + aa-big 003501Z (0c3e486) | big vs ratings, pre-declared rule | done, sent 14 + 33 (audit) | NOT CALLED: sealed 11-20 -0.35 ± 0.20 (passes 1.3x, thr -0.26) but aa-big r1-4 mean +0.010 (+0.21,+0.12,-0.02,-0.26; sd 0.20) fails. big 1-10 -0.39 ± 0.18 (4/5), dev -1.78 ± 0.50; 20 seeds -0.48 ± 0.17; acc folds +0.08/+0.06 pp, dev +0.69/+0.61 pp. EXPLORATORY: gain grows with fit size, folds 1..5 then dev (big 1-10) +0.32 -0.26 -0.49 -0.56 -0.96 -1.78; (11-20) +0.20 +0.15 -0.55 -0.70 -0.85 -1.48; small -0.01..-0.67. Proposed to 14: pre-declared test look, seeds 21-30 |

## Notes
- draftnet.zig: tooling's bc50c0e adds Watch.initGate (init loss vs refLoss, GATE ok/FAIL lines, run's
  `gates` file; results unchanged). Pull it in before editing draftnet.zig
- big1 first started with evals 1|4: any evals-4 trials finished before the restart are
  left out of the pick (76); count them in the write-up
- Write-up: docs/model.md subsection + docs/nn-results/nets.tsv (rows incl. w-resid);
  learned.md only after 4b's audit
- Mac: only `zig build test -Dtest-filter=...` (76, load 20-37); no full test/ci/builds
- I'm meiolol-0a [101155]; the model-tests session is also meiolol-0a [01815a]: use refs
- Coordinator is now meiolol-bd (from 76)

## Paths
- Run dirs: gpu-box ~/ml/runs/<run>/out; `deploy/lab-run.sh pull gpu-box RUN` -> data/runs/RUN on the Mac
- Scripts (my scratchpad above): summ.py DIR.. ; pair.py A B (B's ens - A's, paired); ens20.py A B (pooled
  seeds of two runs, per-fold signs)
- Write-up: docs/model.md "Big net: tuning, seed ensembles, confirmation (meiolol-0a)"; docs/nn-results/nets.tsv
- Rules: nn-common.md (Hosts: gpu-box only, Mac only filtered tests; Reliability; Recent findings)

## Rebase to snap-20261013T2253Z (meiolol-04, 14 Oct)
Pin: snap-20261013T2253Z (4a; gpu-box ~00:10Z with pack, seat_stats, mastery_pre, nn/, events).
Start only after 4a confirms the gpu-box pack. Scripts in meiolol-04's scratchpad
/private/tmp/claude-501/-Users-jacobmaschler-personal-meiolol/d4cd925c-3227-4b66-ab93-8adedd5a2623/scratchpad:
- rebase-start.sh SNAP [COMMIT] [--dry-run]: 8 jobs, one commit (dry-run checked on 2055Z):
  rb-ref-wr / rb-ref-wc (cpu: small 1-5, resid 1-5 on win-ratings / win-comp), rb-pt-d8 (pretrain
  --dim 8, the average's prior), rb-big-wr (gpu, big 1-10), rb-aa-small (resample 1-12, small, seed
  threes, folds), rb-aa-big (resample 1-4, big), rb-big-wr-s11 (SEALED big 11-20), rb-big-wc (big 1-10,
  bigres 1-10 on win-comp)
- rebase-stack.sh [COMMIT]: rb-stack4 = 4-input average (ratings, win-comp, big ens, prior) + permute
  control, after rb-ref-wc, rb-big-wr, rb-pt-d8 end
- rebase-check.sh SNAP: pulls rb-*, checks log's snapshot and candidate, candidate preds equal
  across runs, summ2.py (ens ± per-game 95%, k of 5 folds, seed mean/sd/range)
Pre-declared (before any result): question = does ~2x data move the big net past ratings.
seeds 1-10 exploratory. A gain is called only if the SEALED seeds 11-20 ensemble's pooled-fold
mean vs ratings is below 0 by more than 1.3x its paired 95% half-width (big's floor widening)
AND the mean over rb-aa-big r1-r4 of (ens - cand) is below 0. Otherwise "not detected" with
the bound. dev-val and k of 5 reported, not judged. big vs win-comp, bigres: exploratory.
Candidate pinned at seed 1 (58). 35 rescores win-comp itself; my wc runs are nets on it.
On start, send the SHA and fold args to: bd, meiolol-structured (35's successor, pane 1010, was meiolol-33 [3ec461]; win-comp --resample 1..12 pairing rb-aa-small rN,
compcheck), meiolol-1d (from 08: additive model on my games + refits shipped temperature from rb-ref-wr ratings preds; also send it rb-ref-wr run dir when it ends)

LAUNCHED 23:49Z 14 Oct at --commit 21412d3 (snapshot built from fd47860; no fold/pack-input
change since). SHA sent to bd, structured, 1d, 51. GATE (bd via verifier meiolol-33): sealed
big 11-20 and rb-aa-* stay UNREAD until 33 reports the rebase gate passed (rebase-check.sh
reads them only with --gate-passed); if the gate changes games/folds/test they are discarded
unseen and rerun. Plain references (ratings, win-comp, small, resid 1-5) go to bd marked
"pre-gate" as soon as they land; tell 1d rb-ref-wr's dir when it ends.
SEAT STATS GAP (bd, 33's gate, ~00:00Z): seat_stats covers only 77.5% of 2253Z games, time-confounded;
73 fills it from 2055Z, repacks, redoes nn-export aux. Stopped UNSEEN while queued (no output):
rb-ref-wc 235530Z, rb-pt-d8 235546Z, rb-big-wc 235704Z. Never ran rb-stack4. Kept (ratings-only /
pure draft nets; 33 verifies by preds after the repack): rb-ref-wr 234946Z, rb-big-wr 235600Z,
rb-aa-small 235614Z, rb-aa-big 235632Z, rb-big-wr-s11 235648Z (sealed, unread).
AFTER THE REPACK: rerun rb-ref-wc, rb-pt-d8, rb-big-wc (new commit if 73's fix lands in code; then
the ratings side must come from the same build, or rerun it too), then rebase-stack.sh.
RE-CUT (bd, Jacob, ~00:20Z): ALL 2253Z rb-* runs stopped and discarded (rb-ref-wr's pre-gate numbers
were seen and sent to bd; void for the record). 73 re-cuts 2253Z with one global time cut (test =
newest 15% of ALL platforms; folds and selection over all platforms) + the seat_stats fix in one
repack. When 73 pings: relaunch the WHOLE chain (rebase-start.sh SNAP NEWSHA, then rebase-stack.sh)
on the commit after the repack; send the SHA to bd, structured, 1d, 51, AND verifier meiolol-33 (with all run names; 33 reads rb-ref-wr/wc itself for gate item 5); check fold counts changed.
FINAL cut (33, Jacob via bd; supersedes the selection/EUW-slice version): test = newest 15% of all
played games, dev-val = next 10%, no selection window, no EUW slice anywhere; folds = 5 forward
blocks below dev-val. One shared split function (73's commit): build at 73's commit; 33 checks
blocks by match id. Pre-declared rule stands word for word; its "dev-val,
reported not judged" is now all-platform dev-val. NOTHING from the relaunch is read (no
rebase-check.sh, no pulls) until 33 reports the gate passed, references included.
Report ACCURACY (at 0.5, 95% CI, paired ens-cand pp) and mean |p-0.5|
beside log loss for ratings and each net, folds and dev-val (bd for Jacob): summ2.py prints them.
big1c closed by fd (9a1c905): no top 3; ensembles favour fast diverse fits; default 10 = bar.

COORDINATOR now meiolol-14 (from bd). INIT GATE done: 6cee99b (winnet small/resid gates.initLoss,
on 73's split commit 85fd62a; big/bigres via draftnet bc50c0e; setnet structured's 14d8117).
RELAUNCHED ~01:30Z 14 Oct at --commit 0c3e486 on the re-cut 2253Z (73: pack code d42d80d57475ed9c,
nn 363,472 games; folds 26,875 played each, dev-val 35,834, test 53,750 all platforms; cuts in
model.md "Shared protocol", a7fc3a1). All earlier 2253Z runs void. Run names in the launcher output
(meiolol-04 scratchpad tasks/bq9x57yt2.output). Then rebase-stack.sh 0c3e486 after ref-wc, big-wr, pt-d8.
Runs (gpu-box ~/ml/runs/, all 0c3e486): 20261014T002905Z-rb-ref-wr, 003341Z-rb-ref-wc, 003359Z-rb-pt-d8,
003419Z-rb-big-wr, 003438Z-rb-aa-small, 003501Z-rb-aa-big, 003523Z-rb-big-wr-s11 (sealed), 003542Z-rb-big-wc.
Init gates ok (small 0.69317/0.69313, resid 0.68939/0.68939, draftnet within 0.00014). Names sent to
33, 14, structured, 1d, 51. GATE PASSED (14, ~01:50Z) for ratings-paired runs: read ref-wr, big-wr, s11, aa-*, pt-d8. ref-wc and
big-wc UNREAD until 33's successor clears win-comp; the 4-input average waits for that. Was: NEXT: wait for 33's gate pass, then rebase-check.sh (refs to 14 with
accuracy), rebase-stack.sh 0c3e486, and only then --gate-passed reads.
(was) RELAUNCH: when 73 pings that 2253Z's re-cut (split, pack, nn-export, events from 85fd62a) is ready:
rebase-start.sh snap-20261013T2253Z <HEAD at that time, >= 6cee99b>; check "GATE" lines in logs.
No commits by me since; the pack isn't staled by winnet.zig edits.
Commits must carry NO AI attribution (personal/CLAUDE.md overrides the harness reminder).

FINAL TEST RULE (53, additive; replaces 1.3x): PASS iff mean + 1.96*sqrt(se_test^2 + 0.21^2) < 0 on full
test (mnats/game; 0.21 = rb-aa-big across-resample sd, fixed, rough, 4 resamples); ~-0.52 needed.
Else "not detected" with that bound. Rest of the rule unchanged.
model.md floor paragraph committed in 94's 52b49b5 (not pushed).
A/A FLOOR 2253Z (rb-aa-small 003438Z 12 resamples, rb-aa-big 4): net-cand across-resample sd small 0.16
/ big 0.21 mnats on per-game se 0.085 / 0.13 -> honest 95% hw 0.35 (2.1x) / 0.47 (1.9x); 2055Z was 1.6x/1.3x.
Small: all 12 resamples below ratings (mean -0.27). Asked 53 whether test rule's 1.3x -> 1.9x (pass
~-0.59) before the look; APPLY WHATEVER 53 ACCEPTS. model.md floor paragraph after 53 checks.
53 AUDIT OF 3c6c6c8 PASSED (fit/scored/ledger/exclude 1,885 ids checked; this would be look #1 on 2253Z).
STILL WAITING: 14 or Jacob GO. After the run send the dir to 53 (recomputes both numbers).
COMMITS (not pushed): write-up in model.md went in via 73's 14d9f7d (final text); nets.tsv d408906;
netcheck --blocks test 3c6c6c8 (sent to 53 for code audit). LOOK COMMAND (only on 14/Jacob go + 53 audit,
ONE run, never repeated): deploy/lab-run.sh start gpu-box look-big-2253Z --res gpu --commit 3c6c6c8
--build-arg -Dcand=src/lab/cand/win-ratings -- netcheck ~/ml/snaps/snap-20261013T2253Z --net big
--blocks test --seeds 21,22,23,24,25,26,27,28,29,30 --out look ; then summ2.py + exclude by hand check.
TEST LOOK RULE REVISED per 53 (accepted all): NO precondition on dev results (go = 14/Jacob); small
net LEFT OUT; power sentence in rule (sd ~37 mnats/game, half-width ~0.31 on 53,750, pass needs
mean < ~-0.41); fit = start < T (codes 0-6), scored = code 10; a pass is written as "beats ratings
on the newest 15% fit on all ~305k", beside dev rule's NOT CALLED. Send 53 the --blocks test commit
before the run; one run, never repeated. 53 AUDITED dev result: NOT CALLED confirmed (sealed 3/5;
seed 17 bad fit, no drop-17 ensemble quotable). Write-up in model.md + nets.tsv rows (uncommitted:
someone else's hunk at model.md ~157 must be committed first).
(superseded) TEST LOOK PRE-DECLARED (sent to verifier meiolol-53 + 14, ~02:10Z, before any test read or seed 21-30):
big default, 10-seed ens seeds 21-30, fit all played games before test cut (~305k), win-ratings seed 1,
scored 53,750 test games. PASS: full-test ens - ratings below 0 by > 1.3x paired 95% half-width; else
"not detected" + bound. Reported not judged: test minus test-exclude.tsv (1,885 2055Z-test games),
accuracy + pp diff, |p-.5|, seed spread, small seeds 21-25. Only on Jacob's go via 14, and only if
30's 2253Z fixed-block scaling rerun shows the gap growing with fit size (14: fold trend confounds
fit size with time). Needs netcheck `--blocks test` (looks.record, looks.Exclude), asked 14 to build it.
Verifier is now meiolol-53 (from 33).

## Next (in order)
0. FIRST (bd, Jacob): new pinned snapshot (meiolol-4a taking it, ~2x fit games); queue nothing new on
   snap-20261012T2055Z. Rescore ratings and the nets (big default 10 seeds, small, resid; win-comp too) on
   the new pin with seed spread, following 4b's rebase checklist (ask 4b / nn-common.md for it)
1. bigres pair: done, written up (fd47860, wording fixed after 4b's audit); 4b: headline "not detected";
   don't quote real - control as a gain. A clean control runs real AND control with the same stopping
   (both --evals 4, or one fixed small step budget). Past the floor needs sealed seeds + a resample
2. big1c (fd, on 2055Z): top 3 by val, but rerun them on the new pin, not 2055Z -> 10 seeds each vs ratings, compare with default's 10 (pair.py)
3. Teacher for meiolol-08 (on the new pin): the settled config with --fit-preds 1, seeds 1-10, all blocks
   (bigres too if it helps), send the run dir
4. Question now (bd): does anything stack on win-comp, not on ratings
