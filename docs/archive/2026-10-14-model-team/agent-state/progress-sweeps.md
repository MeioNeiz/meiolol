# Progress: GPU sweeps and lab-run placement (meiolol-1c, fd, then meiolol-37, 13-14 Oct)

Role: own deploy/lab-place.pl (run-time prediction, placement, slot/memory wait) and
deploy/lab-sweep.sh + lab-sweep.pl (random-search sweeps). lab-run.sh (build side, slots,
locks, listing()) is tooling's: meiolol-04 [904e99] (from a0). Coordinator: meiolol-14.
Docs: docs/compute.md "Placement" and "Sweeps". Commit by path, never push (coordinator).

## STOPPED (Jacob out of usage, via meiolol-bd, ~06:15Z 14 Oct)

started nothing new; feeder and watcher stopped. Runs still going: st1-j06
(20261014T061106Z-st1-j06, trial t05, gpu.0), left to finish. st1 state: j01-j05 exit 0
(ref, t01-t04), j06 running, j07-j17 (t06-t16) NOT queued. Resume (same space, draw,
frozen scripts st1py2 in the 7c5b0d73 scratchpad, hash 10b72c0ee7d04710; refreeze from
14a1d89 with git archive if gone): `deploy/lab-sweep.sh start st1 SPACE --trials 16
--python F/state/statenet.py --with F/xcheck/nnsets.py --res gpu --live 1 --skip 6 --
"~/ml/snaps/snap-20261013T2253Z" --kind netd --seeds 5 --epochs 30` (F = st1py2/py)
in the background. No table read yet. pn1 closed. All my commits in (none pushed by me).

## Now (14 Oct ~01:15Z, meiolol-37)

st1 RERUN ~02:58Z: data/sweeps/st1, --live 1, frozen 14a1d89 py/state + nnsets (scratchpad
st1py2, hash 10b72c0ee7d04710), feeder log st1-start2.log (resume: --skip N). j01 = ref,
20261014T025814Z-st1-j01: ref OK (exit 0, 19.9 m, 11.6 GB peak), j02 queued 03:40Z; ~20 m
a job, so ~5.5 h left. A Mac-side watcher (5-min polls) flags any failed st1 job. 41: 11.7 GB RAM per job;
netd beats rich by +0.005..+0.012/game-minute all blocks, permuted control ~0: 41 localising
(neta) before anyone calls it. Table to 41 = ranking on val only.
Later (41): neta (additive: state + champions by minute, no crossing) matches netd's gain
on every block, so netd's edge = champions beyond state, not draft x state. st1 = tuning
for that net; 41 compares the val pick with neta and richc (ridge, CPU-cheap). Ask 41 at
table time whether the --kind nets companion run is still wanted

st1 FAILED ~02:20Z, set aside as data/sweeps/st1-gpuoom (no results read): CUDA OOM at the
0.95/3-slot cap 3.16 GiB (statenet puts the whole block on the card, statenet.py:124-133,
76), and RAM peaks 9.5-15.8 GB per job (j03 OOM-killed with 2 live). 41 fixes statenet;
rerun with --live 1, same space, --trials 16 (same draw). 41 (~02:30Z): HOLD. Use its fix 0b10b1b (data on CPU, batches to card,
every other minute; 5.9 GB RAM, fits 1 slot), not the frozen copy, and only after its
leak control (state-net-perm-2253Zr, ~1h) is clean: netd beat nets by 0.006 on fold 1.
Then st1 at 0b10b1b+ (--control none default), same space; 41 pings. Watch ref end before queuing the rest. Was: 17 jobs (ref + t01-t16), started by a
background `lab-sweep.sh start ... --live 2` (aa6105b) on the Mac, log
/private/tmp/claude-501/-Users-jacobmaschler-personal-meiolol/7c5b0d73-187d-4c16-9992-29f562f39a53/scratchpad/st1-start.log; if that session dies,
resume with `--skip N` (N = jobs in jobs.tsv) and the same args. Frozen scripts:
/private/tmp/claude-501/-Users-jacobmaschler-personal-meiolol/7c5b0d73-187d-4c16-9992-29f562f39a53/scratchpad/st1py (hash 8a1d880518ad911a); 41 told it may edit.
Next: table on val, then val pick with --kind nets --seeds 5 -> 41
pn1 DONE ~03:31Z: default (ref) best on val 0.68200, best trial t06 0.68208, all 12 within
0.0007: no candidate, default stands (folds agree: ref +1.82 ± 0.37 vs trials +1.08..1.65
mnats vs win-exp). Sent to 51 + 14; 51 wrote it up (ca4b630); closed, no sealed check. Was: data/sweeps/pn1, j01 (ref,t01-t06) + j02 (t07-t12), serial cpu, --commit
73be9fe (has 85fd62a), key 903ba2104c3ee368, seeds 10-14. Pick -> 51 as a candidate

1. WAITING: meiolol-73's ping that snap-20261013T2253Z is re-cut (test = newest 15% all
   platforms, dev-val next 10%, folds below). Every 2253Z run before the ping is VOID
2. st1 re-queue on the ping, once meiolol-41 [701543] (name meiolol-state, pane 1000)
   confirms the NEW state export (`meiolol-lab state-export SNAP --every 1 --max 40`):
   `deploy/lab-sweep.sh start st1 SPACE --trials 16 --python py/state/statenet.py
   --with py/xcheck/nnsets.py --res gpu -- "~/ml/snaps/snap-20261013T2253Z" --kind netd
   --seeds 5 --epochs 30`, SPACE = st1.space in this scratchpad (7 flags + ref = 41's
   default). Then: check all 17 run dirs hold the same statenet.py/nnsets.py hash (meta
   `bin` + md5 of nnsets.py), tell 41 it may edit the scripts. When done: table; run the
   val pick's config again with --kind nets --seeds 5 (paired by seed); send both to 41,
   who judges netd minus nets on folds with sealed seeds (val flatters netd). Losses are
   per game-minute. Keep gpu use as is (41: ~6-8 GB RAM per state job)
   The void first run: data/sweeps/st1-void-oldsplit (never read it)
3. pn1 (meiolol-51's playernet, CPU): start after the ping AND 51's message that its
   seeds 4-6 confirmation on 2253Z has ended. `deploy/lab-sweep.sh start pn1 SPACE
   --trials 12 --pack 7 --serial --res cpu --commit 85fd62a+ --build-arg
   -Dcand=src/lab/cand/win-exp -- playernet "~/ml/snaps/snap-20261013T2253Z" --feats
   champ,any,form,rank,prior,duo --threads 3 --seeds 10,11,12,13,14 --evals 4 --clip 1`,
   SPACE = pn1.space here (9 flags + ref). 2 serial jobs (7 + 6 trials), ~3.5-7 h each.
   Seeds 10+ only. Gains vs win-exp (cand_logloss - logloss). Pick -> 51 as a candidate for
   its own sealed check, not a result. 51 (14 Oct): build 85fd62a or later (re-cut split; 942a3d6
   too old). 51 messages when its 10 c-* runs end
4. Possible: meiolol-04 (lead NN, pane 1002) may ask for an ensemble-oriented big-net
   sweep on 2253Z if its references show nets gaining with the extra games: fast lr
   (5e-4..3e-3), short patience, many seeds, ref = defaults
5. meiolol-08 (effects) may ask for a distillation alpha sweep; meiolol-c1/94 (comps) for
   a comp-layer penalty sweep. Both declined for now

Rule while 2253Z results are void/unseen: never print lab-run status/listing log columns
(they carry runs' last log line, i.e. results). Use `| cut -d'|' -f1,2` on status.

## Slot and placement model (gpu-box, live since 14 Oct 00:16Z)

- reserve 4 cores (16-19) for gpu-slot and --res none jobs; cpu.slots 4 x 4 cores (0-15);
  gpu.slots 3; memory gate (0723d43): queue head waits while MemAvailable < its need, at
  most 20 min. FIFO tickets with a fast lane (predicted <= 60 s first)
- lab-place.pl (all committed): history = median of last 5 exit-0 runs by key (same args,
  then command+candidate on snapshot, ..., bare command); python keyed by script
  (BIN python/SCRIPT); linear-work flags --boot and --seeds count scale history; pre-slot
  gpu-box cpu runs x slot/whole ratio (fitted, 3.7); gpu sharing: time ~ sharing^BETA,
  BETA fitted on history (0.69 over 34 runs); wait_for simulates slots + fast lane +
  memory (listing `mem KB`, `peak DIR GB`; need = max peak same bin + first arg, python
  by bin, 4 GB default; running runs give back peak at their end); late rule (edd4d90,
  e37325a): 20 min after the head first sees too little, half its need or no cpu/gpu slot
  held
- Known gaps: parallel packs (`&`) predict as 1 trial (serial ones scale by trials, ee0f61f); cpu history from 5-core slots reads a bit fast on 4-core slots until new
  runs land; the sharing estimate for a new run counts live runs even if it will start
  after they end
- Commits: 7036c3f, 93000da, 7b029b2, 5299b07, 1b56f49, e37325a, ee0f61f, c4fc241 (gpu-share), 3f4095b (memheld, longer of written/fresh pred) (placement); 8826dfe (ref trial),
  bd51189 (--serial, --commit, packed trials pinned via job.sh $pin), dc2f3dc (--python,
  --with) (sweeper). Check with the coordinator which are pushed

## Sweeps done

| sweep | question | result |
| --- | --- | --- |
| smoke1 | sweeper end to end | 2 s trial, +250 MiB GPU |
| big1 | big net with --evals in space | abandoned (evals bias val low) |
| big1b | big net lr/wd/batch/patience, 32 trials x 5 seeds | every config worse than ratings; val favours fast configs |
| big1c | slow big-net training (lr 3e-5..3e-4, batch 1024-4096), 19 trials + ref x 3 seeds, 2055Z | written up 9a1c905 (model.md, nets.tsv): all worse than ratings and than the default's ensemble; averaging 3 seeds gains 0.56 milli-nats (slowest) .. 1.06 (default): ensembles need diverse fast fits. No 10-seed check |
| st1 | 41's state net netd | VOID (old 2253Z split), re-queue on ping |
| pn1 | 51's playernet prior group, 12 trials + ref x 5 seeds, re-cut 2253Z | default best on val; no candidate |

Lessons: sweeps at our size barely rank on inner val; pick on val only, a pick is a
candidate for a sealed seed check; fast fits + many seeds for ensembles; never --evals in
a space; protocol sign: net minus reference, negative = better (sweep tables are reversed:
gain = reference - net, positive = better; say so in write-ups).
