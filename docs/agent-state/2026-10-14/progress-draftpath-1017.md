# progress: draftpath (meiolol-41 [36c2ab], pane 1001)

Brief: scratchpad/brief-draftpath.md (read nn-common.md first). Plan approved by meiolol-bd.
Status 2026-10-14 ~00:20Z: Q1-Q4 DONE on pinned snap-20261012T2055Z, dev only, no test look.
Committed (not pushed; coordinator pushes): commit "draftpath: how drafts win" = docs/model.md
"### How drafts win" (before "### Draft model file"), docs/nn-results/draftpath.tsv (+ README
key), py/draftpath/{dp,info,infogbdt,shape,archsplit,gmed,gmedhist,comeback}.py.
Results summary + reports sent to meiolol-bd. No learned.md line yet: needs meiolol-4b audit
from run dirs AND the rerun on the new pin.

## Audit (meiolol-33, 4b's successor) DONE on 2055Z: no leak; wording fixed and committed
("draftpath: meiolol-33's audit wording"; draftpath.tsv control row). Shuffle control
20261014T000413Z-dp-info-shuffle: draft given state at 15 +0.00015 ± 0.00024 (~0, good).
Open from audit: Q3 indirect per sd disagrees folds (all platforms, ~0 or negative) vs
dev-val (EUW1, +1.6/+1.9/+3.3 at 10/14/20): unresolved, re-measure on 2253Z (dev-val is
all platforms there). Nothing to learned.md until the 2253Z rerun, PRE-DECLARED readings
(send to coordinator + 33 before running): Q1 draft given state at 15 with shuffle
control (also permute within patch x platform: add to info.py), Q3 indirect per sd at
10/14/20 on all-platform dev-val.

## Next
1. Wait: meiolol-73 makes 2253Z re-cut (all-platform test 15%, dev-val 10%), repack and
   nn-export with match_id.txt, then pings; state agent [701543] reruns state-export after
   (its first 2253Z export, 20261013T235532Z, predates the re-cut: check its match_id.txt
   == nn's, dp.load_state asserts it).
2. Then rerun everything on the new pin snap-20261013T2253Z once it has: nn-export WITH
   match_id.txt, state-export (meiolol-41 [701543] said it reruns it there), and meiolol-73's
   re-cut (all-platform test 15%, dev-val 10%) + repack (seat_stats covered 77.5% of 2253Z;
   c1's teams.tsv needs it; rerun c1's `comps --export-teams` or ask c1). Timeline-only and
   champion-id features are unaffected by the seat_stats gap.
   NOTE dp.py sets(): dev = splits 0-5 fit, split 6 scored; check nn-export Split enum is
   unchanged after 73's re-cut (meta.json "splits").
   Then update model.md section numbers + draftpath.tsv rows (edit rows, add a 2253Z note),
   commit by path, tell coordinator, then 4b again; learned.md lines only after 4b.
3. Optional: per-champion g-comp on folds (held-out) not only dev-fit; Q3 at 25 min.

## Commands (all gpu-box, lab-run --python; labpy now caps pools to slot cores, 04's
c8f8136; LightGBM --threads overrides it: keep procs x threads <= 5)
SNAP="~/ml/snaps/snap-20261012T2055Z"
- Q2: deploy/lab-run.sh start gpu-box dp-shape --python py/draftpath/shape.py -- $SNAP --boot 40 (47 min)
- Q1: ... dp-info --python py/draftpath/info.py -- $SNAP (15 min)
- Q1 GBDT: ... dp-infogbdt --python py/draftpath/infogbdt.py -- $SNAP --procs 1 --threads 5
- Q1/Q2 archetypes: ... dp-arch --python py/draftpath/archsplit.py -- $SNAP --info "~/ml/runs/<info run>/info-raw.npy" --teams "~/ml/runs/<c1 export-teams run>/teams.tsv"
- Q3: ... dp-gmed-state --python py/draftpath/gmed.py -- $SNAP --boot 40 ; --gold-only ; --champions --minutes 10,15,20 --boot 20
- Q3 history: ... --python py/draftpath/gmedhist.py --with exp.tsv --with rat.tsv -- $SNAP --exp exp.tsv --rat rat.tsv
  (exp/rat = data/runs/playernet-20261013/r-exp|r-rat/games-cand.tsv, 2055Z only; on 2253Z ask
  meiolol-51 for equivalent out-of-fold win-exp/win-ratings per-game preds)
- Q4: ... dp-comeback --python py/draftpath/comeback.py -- $SNAP ; report-only: --from-raw RUN/comeback-raw.npy
- Wait: deploy/lab-run.sh wait RUN --timeout 580 ; pull: deploy/lab-run.sh pull gpu-box RUN
- Mac analysis: ~/.claude/py/.venv/bin/python (pandas) for small TSVs only; champion names:
  scratchpad (0ffd270b session)/names.json from SNAP/ddragon/16.20/champion.json

## Runs on 2055Z (gpu-box ~/ml/runs, pulled to data/runs)
| id | question | finding |
| --- | --- | --- |
| 20261013T225137Z-dp-nnx | nn match_id.txt | a0 cleared the key; columns byte-identical; ids checked vs events.tsv |
| 20261013T225815Z-dp-shape-a | Q2 | lane gold R2 6-7% (support 13-17%), kills/min 22%, length 5%, first tower 4.2%, win 0.25% |
| 20261013T225917Z-dp-info-a | Q1 | draft alone -0.0011; given state -0.006/-0.013/-0.016/-0.018/-0.017/-0.016 at 5-30, 5/5 |
| 20261013T234038Z-dp-infogbdt | Q1 robustness | GBDT state ties linear; draft given GBDT state 84-88% of linear |
| 20261013T234410Z-dp-arch | Q1/Q2 archetypes | draft given state largest with late scaling / early dive teams |
| 20261013T231454Z-dp-gmed-state | Q3 joint state | per sd total +3.4, indirect -0.8..-0.2, direct +3.5..4.2 (folds) |
| 20261013T235130Z-dp-gmed-gold | Q3 gold only | same within 0.2 pp |
| 20261013T231651Z-dp-gmed-hist | Q3 skill | history moves nothing (weak measure, sd 0.15) |
| 20261013T235144Z-dp-gmed-champ | Q3 per champion | indirect/direct sd ~2 pp each, r -0.8; direct vs 61 shift r 0.91 |
| 20261013T230201Z-dp-comeback-a (+a2) | Q4 | no comeback slope, no mixed-team effect, lane pairs lane-only |
| 20261013T225931Z-dp-mediate-a | old difference method | SUPERSEDED (invalid at 50%) |

## Design notes
- Mediation: research/questions/draft-mediation (meiolol-f1 research), adopted by bd:
  interventional effects by g-computation, probability scale, per sd of out-of-fold draft
  logit; mediator draws = real states of scored games with d within 0.25 sd; Q = logistic on
  state, d, d x state; per champion = swap to role average with state shifted by the
  champion's ridge state effect. No product of coefficients. Indirect share = lower bound
  (noisy mediator). Keep "state carries player skill" caveat prominent.
- Importance: grouped refits only (research verdict): unique / alone / 2-group Shapley.
- State-export is owned by meiolol-41 [701543] (state agent): SNAP/state minute.f32
  [41][n][218] minute-major, game.f32 [n][33]; I only read it.
- Peers: c1 (comp variables, teams.tsv), 61 (carry, closed), 08 (effects; "draft gold
  carries no win"), 51 (f7's successor, player history), 04 [904e99] (lab tooling, a0's
  successor), 4b (audit), bd (coordinator, handed over; successor announces itself and coordinates).
- Context: this session handed over at ~33% (coordinator asked)

## Session meiolol-30 [cc1fb5] (pane 1017), from 01:20Z
- Coordinator now meiolol-14 [8efacb] (bd's successor). Announced to 14, 73, 33, state.
- 2c77211: info.py --shuffle-within (permute inside patch x platform), dp.Nn.patch.
- PRE-DECLARED 2253Z readings (sent to 14 + 33 before any run), 2055Z reference values:
  Q1 primary: "draft given state, minute 15" info.py, folds -0.01633 ± 0.00215 (5/5),
    dev-val -0.0171 ± 0.0035. Holds if folds <= -0.008, 95% CI excludes 0, >= 4/5 folds,
    and dev-val CI excludes 0. Controls (seed 1): --shuffle-draft 1 and
    --shuffle-draft 1 --shuffle-within: each |mean| <= 0.0015 or CI covers 0; else Q1 void.
  Q3 primary: gmed.py joint state, per sd k=1, indirect at 10/14/20, folds + all-platform
    dev-val. 2055Z: folds -0.79/-0.32/-0.20 (sd 0.49/0.52/0.63), dev(EUW1) +1.55/+1.90/+3.30
    (sd 0.97/1.15/1.26). Readings: both cover 0 (|ind| < 2 sd) at >= 2 of 3 minutes ->
    "indirect ~0, the draft acts at equal state"; dev > 0 by > 2 sd at >= 2 of 3 while folds
    don't -> time drift (dev newer), unresolved; folds > 0 too -> revise the write-up.
    Secondary: dev-val EUW1 vs other platforms apart (platform vs time).
- REVISED by 33 (accepted): Q3 branches, cells +/-/0 at 2 bootstrap sd, legs folds + dev-val,
  minutes 10/14/20: (a) neither leg + at 2+, some leg - at 2+ -> "draft's good effect partly
  runs against the early state (scaling)", revise; (b) both legs + at 2+, neither - at 2+ ->
  "runs through the early state", revise; (c) both legs 0 at 2+ of 3, else none -> "indirect
  not detected: |indirect| under B pp per sd", B = max |mean| + 2 sd over 6 cells (bootstrap
  holds d, L2 fixed: a bit narrow); (d) else "unresolved". NO EUW1 reading (Jacob: no EUW
  slice); gmed.py 422a528 prints EUW1/other dev-val as description only. Q1 accepted.
- 33: results unread until 33 reports the gate passed. 33 sends gate reports to 14.
- After 73's ping: ask meiolol-94 [5a3e7f] (comps, c1's successor) for teams.tsv on repacked
  2253Z; ask meiolol-51 for 2253Z out-of-fold exp/rat preds; check meta "splits" unchanged.
- FINAL (33, on file): (a) made symmetric: BOTH legs - at 2+ minutes, neither + at 2+.
  One-leg results of either sign -> (d) unresolved.
- Session renamed meiolol-draftpath (told 14, 33, state, 94, 51).
- 73 DONE: 2253Z re-cut (n 363,472; gpu-box ~/ml/snaps/snap-20261013T2253Z; build >= 85fd62a);
  splits unchanged (0 dev_old, 1-5 folds 26,875 each, 6 dev_val 35,834 all platforms,
  10 test; 7-9 empty) -> dp.sets fine as is. Old 2253Z state export void.
- Asked: state for re-export (needed by every Q), 94 for teams.tsv (dp-arch), 51 for
  exp/rat preds (gmedhist). Then run in order: info (+2 shuffle controls), gmed state,
  shape, infogbdt, gmed gold, gmed champ, comeback, arch, gmedhist. Don't read results
  until 33's gate report.
- 51: exp/rat preds from its c-exp/c-rat confirmation runs on 2253Z, ~1-2 h, provisional until 33's gate.
- 94: export-teams on 2253Z queued after its comp-stats (~10 min, 0c3e486); pings with run dir.
- 14: 33's gate PASSED for draftpath on 2253Z: run Q1-Q4 once state re-export is in. At ~now SNAP/state is still the old export (game.f32 = 298,944 rows), so waiting on meiolol-state.
- 94 DONE: teams.tsv 2253Z gpu-box ~/ml/runs/20261014T005458Z-comps-export-teams-2253Z/teams.tsv; new k-means (wave fixed). archsplit --names "tank/engage,range/siege,AD early dive,late scaling,early dive/roam,enchanter/peel" (from its archetypes.tsv centres)
- 94: comps sealed check (52b49b5): archetypes NOT confirmed -> archetype splits descriptive only in write-up. Confirmed comp effects: magic 60%+, AD share x enemy armour lean, tankiness x enemy pen items. magic_share in teams.tsv looks z-scaled (centres -0.66..0.38): ask 94 for the raw 60% cut before adding a mix split.
- state DONE: 20261014T004121Z-state-export-2253Z-recut (363,472 games, match_id identical).
- 2253Z runs started 01:11Z (gpu-box): 20261014T011058Z-dp-info-2253Z,
  011115Z-dp-info-shuffle-2253Z, 011132Z-dp-info-shufwithin-2253Z, 011149Z-dp-gmed-state-2253Z,
  011216Z-dp-shape-2253Z, 011238Z-dp-infogbdt-2253Z, 011301Z-dp-gmed-gold-2253Z,
  011323Z-dp-gmed-champ-2253Z, 011344Z-dp-comeback-2253Z. Pending: dp-arch (needs info run's
  info-raw.npy), gmedhist (needs 51's preds).
- archsplit: mix groups added (raw magic_share, cuts 0.2/0.6 per 94). 94's export -b (phys_share, armour_lean, pen appended) running as 20261014T011109Z-comps-export-teams-2253Z-b; first 17 cols same, either file works.
- 51 DONE: exp data/runs/20261014T003827Z-c-exp/out/games-cand.tsv, rat .../20261014T004141Z-c-rat/out/games-cand.tsv (staged as data/runs/dp-hist-in-2253Z/{exp,rat}.tsv). gmedhist run started.
## 2253Z PRIMARY RESULTS (01:35Z)
- Q1 PASS: draft given state 15 folds -0.020087 ± 0.001226 5/5, dev -0.021620 ± 0.002382.
  Controls: shuffle -0.000012 ± 0.000101 (dev +0.000142 ± 0.000209); within patch x platform
  +0.000006 ± 0.000096 (dev +0.000125 ± 0.000170). Draft alone now -0.0041 folds / -0.0052
  dev (2055Z -0.0011): ratio ~5x folds, ~4x dev (NOT 15x). Given state: 5 -0.0100, 10 -0.0164,
  15 -0.0201, 20 -0.0214, 25 -0.0200, 30 -0.0188 (fewer games). beta ~1.1-1.5 at 10-20, ~0.8-1.2
  at 30. Per role at 15: mid -0.0050, bot -0.0048, sup -0.0042, jg -0.0035, top -0.0031.
- Q3 branch (c): cells (indirect ± sd) folds 10 -0.05±0.24, 14 +0.31±0.29, 20 +0.77±0.35(+);
  dev 10 -1.04±0.43(-), 14 -0.29±0.56, 20 +0.80±0.76. "indirect not detected: |indirect|
  under 2.31 pp per sd" (dev 20). Total ~4.5 pp/sd folds, direct 4.7/4.3/3.7 at 10/14/20.
  Description: both legs drift from negative at 5 to positive at 20. EUW1 rows description only.
- verifier now meiolol-53 (33's successor); primary readings sent to 53 + 14.
- 53 AUDIT PASSED Q1 + Q3 (2253Z). d133a04: model.md Q1/Q3 -> 2253Z (2055Z kept for record;
  GBDT/arch/Q2/gmed-gold/hist/per-champ/Q4 marked "2055Z"), draftpath.tsv Q1 rows -> 2253Z,
  learned.md Win line (early, 2253Z). Not pushed (coordinator pushes).
- NEXT: when bk5vq46e5 wait ends, pull the 7 replication runs, replace the 2055Z-marked parts
  (+ draftpath.tsv GBDT and lane rows), commit by path, send 53 anything carrying a reading.
- eda20b5: learned line fixes (53). 0c0a62e: all replication parts -> 2253Z (every reading
  repeats). Sent 53 two possible readings (GBDT now beats linear; top lane pairs -0.00021,
  under floor, a lead). Told 14; commits unpushed: 2c77211 422a528 61c57ff 6d03d1c d133a04
  eda20b5 0c0a62e. Open leads: top lane pairs pre-declared check; per-champion on folds.
- 0d4d575: 53's replication wording (GBDT 'at most a fifth, possibly less'; top lane = 1d's matchup signal; learned line 'four to five times', 'about as large at 30 among games still going'). Draftpath CLOSED pending coordinator; unpushed: 2c77211 422a528 61c57ff 6d03d1c d133a04 eda20b5 0c0a62e 0d4d575.
