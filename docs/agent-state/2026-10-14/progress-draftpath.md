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
