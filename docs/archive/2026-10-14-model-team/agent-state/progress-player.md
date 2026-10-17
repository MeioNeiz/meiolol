# progress-player: player-history nets, internal scope (meiolol-51, from f7; 2026-10-14 00:10)

Read first: shared brief nn-common.md (Hosts: gpu-box ONLY, never run binaries or extra
builds on the Mac; only `zig build test -Dtest-filter=YOURS`), docs/lab-constraints.md,
docs/model.md "#### Player-history nets, internal scope (meiolol-f7)" (all results so far).
Coordinator: meiolol-bd. Verifier: meiolol-4b (or successor). Data/rows: meiolol-4a.
Commit by path; no push; Zig is ~/.local/bin/zig (Homebrew's is 0.16).

## Code (all committed)
- src/lab/playernet.zig (`meiolol-lab playernet SNAP`): per-slot net residual on -Dcand.
  Options: --feats champ,any,form,rank,mastery,prior|none, --emb 0, --fix-offset 1,
  --shuffle-feats 1 (leak control: pass = not better than cand), --shuffle-labels 1
  (uninformative), pub healthFit/NetGame for lab/health.zig (model-tests meiolol-0a
  [01815a]). preds.tsv has per-side history counts b_/r_ (calibration, 4a's slices)
- Candidates: src/lab/cand/win-exp (ratings + champ_exp + form = "hand-made terms",
  the reference), src/lab/cand/win-exp-first (+ played-before step, cfg champ_played)
- Rows (abb57f3): Row.player (dense id, internal only), gpm/cspm/dpm_before,
  offrole_before, days_since_last (NaN when none). 4a repacking gpu-box snapshots
- Tools: data/runs/playernet-20261013/{pair.sh A COL B COL, calib.sh PREDS COLS..., games.sh RUN NAME}
- Runs: `deploy/lab-run.sh start gpu-box NAME --commit SHA --res cpu --build-arg
  -Dcand=src/lab/cand/win-exp -- playernet '~/ml/snaps/<snap>' --seeds 1,2,3 --threads 3
  --feats ... --out out`; `lab-run.sh pull gpu-box RUN` -> data/runs/RUN/out

## Findings (dev only, no test look; written up in model.md, nn-results/player.tsv)
- Experience terms vs ratings: -0.0026 (2055Z), -0.0038 (1954Z), 5/5 folds; grows with history
- Net beyond hand-made terms: -0.0002..-0.0003 every run, under noise floor ~0.0005:
  NOT established. Permuted-feature control +0.0002 (no leak). 4b audited 2055Z: no leak
- Calibration: win-exp under-reacts to who has played their champion (~+2 pp at blue
  <= -2 such players); win-exp-first narrows it, log loss gain not detected

## In flight
- pq-* cancelled (f7); pd-* done on 1954Z (first look above); pe-* cancelled (bd)
- Commits: d43fa92 (--feats duo group), 535d48e (--resample N)
- New pin snap-20261013T2253Z (packed with abb57f3's Row fields; 1954Z not repacked).
  Item 1 there, one build (cb19e68 or later), cands win-ratings and win-exp:
  pn-rat (cand win-ratings, feats champ,any,form,rank), pn-exp, pn-exp-pfeat,
  pn-exp-prior (prior incl. duo), pn-exp-prior-pfeat. Report win-exp vs ratings against
  1954Z's -3.8 (bd), rank_start coverage, calibration buckets; games files for 4b
- 4a's line for model.md: win-exp gain over ratings by players with champion history
  0/1-2/3-4/5+, mnats: 2055Z -0.4/-2.1/-4.1/-3.7 (all -2.5 ± 0.7); 1954Z
  +0.2/-3.5/-5.1/-5.1 (all -4.0 ± 0.6) (already in learned.md d1d435b)

## Pre-declared confirmation: prior + premade beyond win-exp (written 2026-10-13 23:20Z,
## before any run on the pin; verifier meiolol-33)
First look (1954Z, cb19e68, seeds 1-3; NOT citable, binary from a0's build-lock window):
pd-exp-prior vs pd-exp -1.34 ± 0.29 mnats folds, control +0.24, gain rises with history.
a0 (23:3xZ): pd-* and player-rat-cal-1954Z binaries match clean rebuilds; player-first-* too
Still first look only (bd): the confirmation is 2253Z.
Confirmation on snap-20261013T2253Z only, one build 535d48e, cand win-exp, seeds 4,5,6
(sealed: never run before), all blocks (dev, folds 1-5):
- A  c-exp:   --feats champ,any,form,rank
- B  c-full:  --feats champ,any,form,rank,prior,duo
- A/B again with --resample 1 and --resample 2 (netcheck's 90% draws)
- control c-full-pfeat: B with --shuffle-feats 1
- split (descriptive, not in the pass rule): c-prior (+prior), c-duo (+duo)
- reference c-rat: cand win-ratings, --feats none, seed 4 (win-exp vs ratings row, vs
  1954Z's -3.8)
Statistic: per game, B's 3-seed ensemble log loss minus A's (pair.sh ens), folds pooled,
95% half-width paired by game. Pass (35's rule): full-data mean + 1.6 x half-width < 0,
both resamples' means < 0, and >= 4 of 5 fold blocks negative; control: c-full-pfeat
vs its candidate not better than -0.5 mnats (else a leak, verdict void). dev-val
reported beside it, not in the rule.
33 accepted the rule (23:2xZ). Start ONLY after bd pins 2253Z (gate items 1-5); launch
script: this session's scratchpad confirm.sh (copy in progress dir if handed over). In the
write-up: gain per fold block beside pooled (coverage grows with crawl depth), say pd-*
used seeds 1-3 only, learned.md line internal scope. 33 checks cand preds byte-equal
within each resample draw and blocks vs nn/split.u8. Also reported: gain by players with history
(0-4, 5-7, 8-9, 10 of ten), offset weights, seed spread.

## Next, in order
1. Premade as a hand term in win-exp (per role, team's count of premade pairs) and the
   gain split by premade games vs not, once pd-* says whether it matters
2. New pinned snapshot (4a taking it, ~double, more rank_start): rerun the main rows
   (win-exp vs ratings, net on win-exp, pfeat control) there, rank group on
3. Prior as hand-made terms in win-exp (gpm/cspm/dpm/offrole/days per role, trust-
   weighted), split gain by history length (4a's buckets: champ-history players
   0/1-2/3-4/5+, total earlier games 0/1-19/20-59/60-149/150+), with pfeat control
4. Base player skill + champion/role offsets shrunk by games (TrueSkill 2-style)
5. Rank at start + unconverged flag (19 Oct snapshot); session/tilt: time-split test only
- Pending lab-constraints lines (file had others' edits): Homebrew zig 0.16 first on
  PATH (use ~/.local/bin/zig); HEAD broken by an import of an untracked file (deecc3f)

## Side work
- 942a3d6 `--dump 1` (net inputs per block/part, for 58's PyTorch rebuild); run
  pn-dump-2055Z (win-exp, seed 1) restarted after a gpu-box ssh drop; send 58 the dir
- fd will sweep playernet (CPU, seeds 10+, after the confirmation; space sent 23:4xZ);
  its pick needs its own sealed check
- Confirmation launched ~23:55Z on 535d48e (bd: own build is fine, 04's SHA not needed);
  run names c-exp, c-full, c-full-pfeat, c-exp-r1/-r2, c-full-r1/-r2, c-prior, c-duo,
  c-rat. UNREAD until 33 reports the rebase gate passed (discard unseen if the gate moves
  games, folds or test)
- fd's sweep pn1 ready (942a3d6, seeds 10-14, 13 trials, 2 slots serial): TELL fd when the c-* confirmation runs end
- 04's 2253Z rebase commit: 21412d3 (only for pairing against 04's reference preds; bd: mine stay on 535d48e)
- 00:0xZ PROTOCOL CHANGE (Jacob via bd/33): 2253Z repacked by 73 with one global time
  cut (test newest 15% all platforms, selection 10%, dev-val 5%, 5 equal-count forward
  folds below; EUW1 a slice). All c-* runs stopped unread (discarded). Rule stands; rerun
  after repack on a build whose blocks follow the new protocol (asked 33/73 whether
  harness gets a shared blocks function; playernet copies winnet's EU-cut block code).
  807f100: playernet uses harness.inResample directly
- 33 accepted: build at 73's commit with the shared harness split function (T, D, fold
  bounds) as the only deviation. Final protocol: test newest 15% all games, dev-val next
  10%, no selection window, no EUW slice. When 73 lands it: switch playernet's block code
  (and harness.cuts use) to it, filtered test, commit, rerun confirm.sh with that SHA
- Coordinator now meiolol-14. c4e8077: init-loss gate (gates.initLoss vs offset loss).
  7456304 (unpushed) swept in 73's uncommitted playernet split switch; c4e8077 reverts it.
  73's playernet edit sits in the working tree: 73 commits it with its harness change;
  confirmation builds at that SHA. LESSON: before a by-path commit, `git diff` the file;
  others may have edited it (filtered tests don't analyse main())
- 73 committed the split (85fd62a, includes playernet's switch). confirm-player.sh now
  builds C=85fd62a. START ONLY on 73's ping that 2253Z's re-cut pack + nn-export are
  ready (an old pack fails with TestWindowMismatch); then tell 33 the build is 85fd62a
- draftpath wants win-exp (c-exp cand) and win-ratings (c-rat cand) games-cand.tsv on 2253Z: games.sh on those run dirs, send paths (provisional until 33's gate)
- 04's re-cut rebase commit 0c3e486 (85fd62a + winnet gate): pair against 04's refs only; my runs at 85fd62a
- 14: 85fd62a fine, no rebuild. Gate PASSED (14 via 33): may read c-* results. Tell 37 to queue pn1 when c-* end

## RESULT (01:30Z): confirmation PASSES (2253Z re-cut, 85fd62a, seeds 4-6)
B-A folds -1.95 ± 0.31 (5/5), r1 -1.72, r2 -1.97, dev-val -2.84; control +0.05; prior only
-2.06, duo only -0.07; by history 0-4 -1.30 .. 10 -3.01; win-exp vs ratings -5.07; B vs
ratings -7.43. Written: model.md + player.tsv (a55eaaa). Audit packet sent to 14 (33 gone;
14 to forward). draftpath has c-exp/c-rat games-cand.tsv. pn1 released to 37.
learned.md line only after audit (internal scope).
## Next
1. Which prior feature carries it (ablation: --drop FEAT or per-feature groups)
2. Prior as hand-made terms in win-exp (needs api.Experience fields? check owner)
3. (DROPPED: e8 found offset averaging gains nothing in torch on 2253Z, f89bc8c)
4. Base skill + champion/role offsets (TrueSkill 2-style); rank once coverage allows
- 6769b8c --drop + refAllDecls compile test. Ablation runs ab-full, ab-no-{gpm,cspm,dpm,offrole,days_since,rates} on 2253Z seeds 1-3 (descriptive): pair each vs ab-full ens
- pn1 queued by 37 (73be9fe, key 903ba2104c3ee368, 2 serial jobs, seeds 10-14); its val pick comes back as a candidate for a sealed check
- 53 AUDITED + CONFIRMED. learned.md line 9bfcefc (Win, 2026-10-14 (2253Z): How players
  did in their earlier games...). overlap-2253Z (53's optional check) running: send 53 result
- Next 2 (hand terms in win-exp) needs history means in api.Experience: asked 14 who owns api
- pn1 DONE: no trial beats default on inner val; folds agree. model.md ca4b630. No sealed check needed
- Ablation DONE (ca91496): rates (gpm,cspm,dpm) carry +1.60 of ~2.1; dpm alone +0.66;
  gpm/cspm redundant; offrole, days_since ~0. Overlap check: 0 overlaps (sent to 53)
- So for hand terms in win-exp: per role, trust-weighted dpm (+ one of gpm/cspm) per
  player, blue minus red; dpm may partly be champion pool (consider dpm relative to the
  champion's mean)

## Pre-declared: history means as hand-made terms (win-exp-rates vs win-exp), 2026-10-14
## ~02:10Z, before any run; verifier meiolol-53
Build fd39d1e, snap-20261013T2253Z (re-cut), playernet --feats none --seeds 1 (the
candidate column is the statistic; the featureless net is ignored), all blocks.
Runs: h-exp (-Dcand win-exp), h-rates (-Dcand win-exp-rates), each also with
--resample 1 and --resample 2 (6 runs).
Statistic: per game, win-exp-rates cand log loss minus win-exp cand's, folds pooled,
± 95% paired by game. Pass: full-data mean + 1.6 x half-width < 0, both resample means
< 0, >= 4 of 5 blocks negative. Dev-val reported beside it. Descriptive, not in the
rule: the gap to playernet B (c-full ens, 85fd62a): how much of the net's history-means
gain the hand terms recover; and h-rates-net: playernet on win-exp-rates with
--feats champ,any,form,rank,prior,duo, seeds 1-3 (what the net still adds).
53 ACCEPTED (02:1xZ). Write-up framing: engineering result ("hand-made rate terms recover
X% of the confirmed -0.00195"), not new evidence; a fail = "not captured by these terms".
k=3 and role standardisation fixed as in fd39d1e, no retuning (variants = new declared
runs). Report resample spread beside the 1.6x. Send 53 the run dirs.
- 04:xxZ win-exp-rates PASSES (ab9ee78): -1.91 ± 0.36 folds vs win-exp, 5/5, r1 -1.77, r2
  -1.80; net's edge over it -0.45 (under floor). Sent to 53 for audit. If cleared: amend
  the learned line (simple per-player averages capture it), then next: base skill +
  champion/role offsets (TrueSkill 2-style), or dpm relative to champion mean (declared)
- 53 AUDITED win-exp-rates: PASS. learned line amended (37eef09): rate terms capture most to all. Next: (a) dpm relative to champion mean (declare first), (b) base skill + offsets
- Asked 14 (05:xxZ): batch (a) champion-relative rates + (b) shrunk player skill rating into one rowsql commit (4a review, one repack) or wait for next snapshot
- calib on 2253Z: rates don't fix bucket gaps (games gap non-monotone, up to 1.4 pp): lead = games-count spline/buckets per role (declared run; no rowsql needed, win-exp cfg)

## Pre-declared: win-exp-shape vs win-exp-rates (accepted by 53, ~05:xxZ, before runs)
win-exp-shape = win-exp-rates + one-hot earlier games 1-19/20-59/60-149/150+ and champion
games 1-2/3-9/10+, per role. Runs s-rates, s-shape (+ -r1, -r2): playernet --feats none
--seeds 1, one build, 2253Z. Statistic: shape cand minus rates cand, folds pooled.
Pass: full mean + 1.6 x hw < 0, both resample means < 0, >= 4/5 blocks negative, AND
dev-val mean < 0 (53's addition: folds wearing thin, third design chosen on them).
Write-up caveat: counts are games in our crawl; bucket thresholds encode crawl depth;
a pass is about this dataset's coverage; live lobbies need the counts redefined.
Report calibration gaps before and after.
- shape runs launching (6b997d2): s-rates, s-shape, -r1, -r2; ids in e7ef scratchpad shape-runs.txt; analysis: adapt hand.sh (h-exp->s-rates, h-rates->s-shape) + dev-val leg + calib
- 14 (coordinator) 'waiting', inbox full: 3 msgs dropped (d2c836d0 had: 53 cleared rates, shape lead, rowsql decision). Send ONE later; rowsql items deferred until 14 answers. Unpushed by-path commits since a55eaaa incl. 37eef09 1c1b926 e65268e 6b997d2
- win-exp-shape FAILS (e061f27): folds +0.16 ± 0.21, 2/5; narrows calib gaps w/o log loss gain. Sent to 53. Remaining ideas need rowsql (14 to decide) -> otherwise write up + hand over
- 53 closed shape track (don't retune; new bucket designs = new declared run, ideally later pin). Asked bd (14 unreachable) to push + decide rowsql vs next snapshot
- bd (06:xxZ): write rowsql change now, reviewed by 73, NO 2253Z repack; judge both on
  the NEXT pin (73 re-pins at +50% games or weekly); pass rule declared before that pin.
  bd pushing my commits. Written, UNCOMMITTED in working tree: rowsql.zig
  (gpm/cspm/dpm_rel_before in fillExperience; skill_before via fillSkill, lr 0.1, n0 10)
  + pipeline_test.zig checks; diff saved as rowsql-skill-rel.diff here. Asked 73 to review
  and say commit now vs just before next pin (commit stales every pack)

## Pre-declared for the NEXT pin (written 2026-10-14 ~06:30Z, before that pin exists;
## bd's decision; verifier meiolol-53)
Code: rowsql-skill-rel.diff (this dir): Row.gpm/cspm/dpm_rel_before (champion-role
relative rates) and Row.skill_before (fillSkill: lr 0.1, n0 10, fixed). NOT in the tree
(bd: no dirty rowsql in the shared tree; stales packs). At re-pin: apply the diff, review
by the data agent (73's successor) or 53, commit by path BEFORE the pack. Then, without
touching the pack again: api.Experience gains rel rates + skill (harness.experience maps
them, 0 when unknown), win-exp cfg flags `rel` (3 terms, standardised by role on training
rows, trust n/(n+3) with rate_games) and `skill` (skill_before per role, no trust: the
rating is already shrunk), copies win-exp-rel and win-exp-skill = win-exp-rates + one
flag each (keep copies in step).
Runs (one build, new pin): playernet --feats none --seeds 1, -Dcand win-exp-rates (A),
win-exp-rel (B1), win-exp-skill (B2), each full + --resample 1 + --resample 2 (9 runs).
Statistic per B: B cand log loss minus A cand, per game, folds pooled, paired 95%.
Pass, each B on its own: full mean + 1.6 x half-width < 0, both resample means < 0,
>= 4 of 5 blocks negative, dev-val mean < 0. Report both whatever the outcome; two
hypotheses, so name it if only one passes narrowly. Also report calibration by history
bucket (calib.sh) for A, B1, B2. Caveats: history = our crawl; skill is outcome-based
from earlier games only (like wins_before), internal scope.

## BRIEF FOR THE SUCCESSOR (meiolol-51 handover, 2026-10-14 ~06:40Z)
State: nothing running. Tree clean for my files. All my commits pushed by bd (check
`git log origin/main` contains e061f27). Coordinator meiolol-14 (stuck "waiting" on Jacob;
bd covering). Verifier meiolol-53. 2253Z folds are spent for player designs (3 chosen).
Done and audited (model.md "Player-history nets", learned.md Win 2026-10-14 (2253Z)):
history means confirmed (-1.95 mnats beyond the net on win-exp); win-exp-rates captures
most to all (-1.91 vs win-exp); premade not detected; games-count buckets fail.
Next, in order:
1. At the next pin (73's successor re-pins at +50% games or weekly): apply
   rowsql-skill-rel.diff, review by the data agent or 53, commit by path BEFORE the pack;
   then api/harness/cand work and the 9 runs exactly as "Pre-declared for the NEXT pin"
2. Also on the next pin: rerun the main rows (win-exp vs ratings, win-exp-rates vs win-exp)
   to see the history gain keep growing with data (2055Z -2.6, 1954Z -3.8, 2253Z -5.1)
3. Rank at start + unconverged flag once rank_start coverage allows (1% on 2253Z)
Rules learnt: git diff a shared file before a by-path commit; test on a `git archive HEAD`
export when the shared tree doesn't compile; playernet's refAllDecls test compiles main()
53 ACCEPTED the next-pin B1/B2 rule (06:4xZ) with code conditions, reviewed at re-pin:
(1) skill_before: brute-force test recomputing each row's skill from a scan of games
    ended by its start (end <= start), with overlapping and same-player games, >= 1
    overlap required (the diff's test is hand-computed only: ADD this)
(2) rel terms' champion-role mean: same end <= start rule, excludes the row's own game;
    brute-force test likewise (note: running mean is order-dependent among equal end
    times; make the test's scan match, e.g. distinct end times in the fixture)
(3) rel standardisation and trust from training rows only (as win-exp-rates)
(4) write down: two candidates, no multiplicity correction; "B1 and B2 each tested;
    neither result conditions the other"
(5) run notes: which new-pin fold games were in 2253Z's folds

## meiolol-74 (successor of 51), 2026-10-14
- 53's conditions (1) and (2) done in rowsql-skill-rel.diff (v2; v1 kept as .v1.diff).
  New test "relative rates and skill count only games ended by the start, brute force":
  400 games, ends distinct per game (start gi*600_001 ms), players and champions distinct
  within a game; skill replayed from zero per game over games with end <= start in end
  order; rel recomputed per earlier game over champion-role games ended strictly before
  it. Fixture: 1886 overlapping earlier games, 3488 rel rows, 3543 nonzero skill (of
  4000). Mutations caught: skill window end <= start + 10 min; rel mean including the
  game itself. rowsql 20/20 and pipeline fixture tests pass on a HEAD export + diff
  (Zig 0.17 at ~/.local/zig/zig-aarch64-macos-0.17.0/zig; /opt/homebrew zig is 0.16)
- Still open at re-pin: (3) rel standardisation and trust from training rows (harness /
  win-exp code), (4) and (5) write-up items
