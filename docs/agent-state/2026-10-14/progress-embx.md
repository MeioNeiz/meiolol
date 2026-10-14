# progress: embx (meiolol-ab, session 6dd51e50)

Question: do low-rank pair interactions on frozen pretrained champion-role embeddings add to win-comp (ratings + mix)?

Code (all committed): deecc3f api.Options.embeddings + `meiolol-lab --emb DIR` (lab_main) + lab/embfiles.zig (exact per champion-role fit-game match, test) + cand/win-embx; 2b60f64 lab_main fix; 815e201 comptime `variant` (all), no in-candidate folds; a7961de `seed_offset` (sealed seeds), embfiles takes block "final"; 99bc305 = offset 3 all, e771256 = offset 3 shuffled, 68c249c defaults again. In-candidate fold table of every variant: set cfg.folds = 5 (deecc3f's run).
Write-up: model.md "Interactions on pretrained embeddings (meiolol-ab)" (ab3582e, 42cdafd), docs/nn-results/embx.tsv.

Runs (gpu-box, snap-20261012T2055Z, d12 E seeds 1-3)
- R1 20261013T215827Z-embx-all (deecc3f): in-candidate folds, 3 seeds avg: all vs mix -0.00034 ± 0.00021, within -0.00020, cross -0.00005, both -0.00006, lane +0.00026, shuffled +0.00012; single seeds tie with mix
- R2 netcheck per-game: nc-win-embx, nc-win-comp, nc-win-ratings (815e201); nc2-* (ec9224a) + nc-win-embx-shuf (0c75817). compare (embx-compare, embx-compare2): folds only (4b) all vs comp -0.00037 ± 0.00023 (5/5 folds neg), vs shuffled -0.00046 ± 0.00025, shuffled vs comp +0.00009 ± 0.00017; dev-val tie
- 4b audit: no leak sign, at floor (needs ±0.37). Pass rule declared (model.md): sealed E seeds 4-6, folds only, all vs win-comp mean < 0 by > 1.6x half-width AND vs sealed shuffled < 0. Caveat (4b): seeds don't cover fit-game resampling noise; on the new pin add pretrain --resample leg
- R3 done: pt-d12-s456 (pretrain at 99bc305, seeds 4-6; a88db2d won't build under current lab-run; 74e059d scaling fix differs from d12). Then netcheck at 99bc305 (all), e771256 (shuffled), win-comp at 99bc305, all with `--emb <pt run>/d12s`; compare --by-block on folds only

- R3 result (2bff78d, model.md + embx.tsv): sealed folds only all vs win-comp -0.00037 ± 0.00024 (5/5 folds negative), vs shuffled -0.00052 ± 0.00025, shuffled vs comp +0.00015 ± 0.00019; declared rule (1.6x = 0.00038) NOT passed by 0.00001: not confirmed. Runs 20261013T234123Z-nc-sealed-all, 234637Z-nc-sealed-shuf, 235234Z-nc-sealed-comp, 235419Z-embx-sealed-cmp (folds-only via awk dropping block dev, compare --allow-build). 4b was unreachable for the sealed result: tell its successor (ask meiolol-bd who)

Notes: lab-run needs PATH=$HOME/.local/bin:$PATH in my shell (Homebrew zig 0.16 first otherwise); --commit SHA for every start (shared tree often broken); one-word --desc; variant/seed_offset are comptime: commit a variant, start with --commit, commit defaults back. Starts can take 5-10 min (shared build lock): run in background. Mac: no runs, only `zig build test -Dtest-filter=...`.

Next (successor): the new pin snap-20261013T2253Z: pretrain E per block (seeds 1-3, plus sealed 4-6), win-embx all vs win-comp, shuffled control, pretrain --resample leg (E per 90% set; embfiles needs those files; 4b asked for it as the second leg: pretrain learns E on each 90% set, then win-embx on the same set via netcheck --resample). Coordinator meiolol-bd approved the new-pin rerun (snap-20261013T2253Z on the gpu-box). Declare the pass rule in model.md before the seeds land

## meiolol-64 (session 35e18589), from meiolol-ab
- 33 = verifier now (4b handed over); sent it the sealed result + new-pin rule
- daa56a0: pretrain --resample N (harness.inResample shared with winnet; test "pretrain resample")
- 2e79c64: new-pin pass rule declared in model.md (sealed 4-6 past 1.6x, below sealed shuffled, resample leg < 0; folds only vs win-comp same build)
- HOLD (bd): 2253Z seat_stats only 77.5%, meiolol-73 repacking; start after, discard anything earlier. Results unread until 33 passes rebase gate
- Plan once repack lands (snap ~/ml/snaps/snap-20261013T2253Z, --commit, --procs low):
  P1 pt-2253-s123: pretrain SNAP --seeds 1,2,3 --out e (daa56a0)
  P2 pt-2253-s456: pretrain SNAP --seeds 4,5,6 --out e (daa56a0)
  P3 pt-2253-rs1: pretrain SNAP --seeds 1,2,3 --resample 1 --out e (daa56a0)
  N1 nc-2253-all: --emb P1/e netcheck SNAP --net small --max-epochs 1 --seeds 1 --out out, -Dcand win-embx on 04's post-repack commit (pair w/ its win-comp; 21412d3 dropped, 2253Z re-cut: one global test cut, dev-val 10%)
  N2 shuffled seeds 1-3, N3 sealed all (seed_offset 3 commit), N4 sealed shuffled, N5 win-comp at sealed commit (check = 04's), N6/N7 netcheck --resample 1 win-embx (--emb P3/e) and win-comp
- 33 accepted rule (a)-(c) + dev-leg change; 3dea306 adds "one resample draw agrees" wording. 33 recomputed 2055Z sealed: not confirmed
- Re-cut protocol (Jacob final): test = newest 15% of all played, dev-val = next 10%, folds = 5 forward blocks below, no selection, no EUW slice. Run at a commit WITH 73's shared split fn (not landed as of 3dea306); 33 checks blocks by match id vs nn/split.u8. Wait for 73's ping
- Coordinator now meiolol-14. It asked for gates.initLoss in pretrain/embx fits; I replied it's vacuous (zero-init linear logits = 0.5), proposed skip or pretrain trainRatings only after 73's dirty pretrain.zig hunks land. Awaiting 14's answer
- DECIDED (14): no init-loss gate (gates.initLoss) in win-embx or pretrain: zero-init linear logits make a fresh fit exactly 0.5, and E-term passes start exactly at the frozen offset, so it can't fire. Candidate and harness untouched. Revisit only if a fit moves to random init or gets a hidden layer
- 73: 2253Z re-cut+repacked (build >= 85fd62a). Commits: ba9a21a shuffled off0, e108ca6 all off3, 9f2b179 shuffled off3, 44ca8ee defaults (all off0)
- STARTED (gpu-box): pt-2253-s123/s456/rs1 (44ca8ee, --out e); nc-2253-comp, nc-2253-comp-rs1 (--resample 1) at 44ca8ee; nc-2253-sealed-comp at e108ca6. Next after pretrains: nc-2253-all (44ca8ee, --emb s123/e), nc-2253-shuf (ba9a21a, s123), nc-2253-sealed-all (e108ca6, s456), nc-2253-sealed-shuf (9f2b179, s456), nc-2253-all-rs1 (44ca8ee, --emb rs1/e, --resample 1). Results unread until 33's gate
- Done: 20261014T004122Z-pt-2253-s123, 004141Z-pt-2253-s456, 004200Z-pt-2253-rs1 (exit 0, 18 emb files each; f1 fit 134,375 games, rs1 120,961 = 90%). win-comp: 20261014T003341Z-nc-2253-comp (44ca8ee), 003400Z-nc-2253-comp-rs1, 004017Z-nc-2253-sealed-comp (e108ca6, same run key as nc-2253-comp)
- Starting the 5 win-embx netchecks (bv3c52q4j task)
- Done, clean, UNREAD: 20261014T013014Z-nc-2253-all (44ca8ee), 013425Z-nc-2253-shuf (ba9a21a), 013920Z-nc-2253-sealed-all (e108ca6, s4-6), 014336Z-nc-2253-sealed-shuf (9f2b179, s4-6), 014358Z-nc-2253-all-rs1 (44ca8ee, rs1 E, --resample 1). Each 18 E files loaded, 0 GATE FAIL
- Verifier now meiolol-53 (from 33). Sent it the run list + rule; waiting for rebase gate. Then compare folds only (awk drop block dev, compare --allow-build as in 235419Z-embx-sealed-cmp): (a) sealed-all vs sealed-comp, (b) sealed-all vs sealed-shuf, (c) all-rs1 vs comp-rs1; dev leg all/shuf vs nc-2253-comp. Write up model.md + embx.tsv
- RESULT (53 audited, my 20261014T033741Z-embx-2253-cmp reproduces): DETECTED at margin. (a) -0.00026 ± 0.00014, (b) -0.00032 ± 0.00014, (c) -0.00052 ± 0.00018, all 5/5; dev leg -0.00040; shuffled ties; vs ratings -0.00074 (comp -0.00048). At 04's 2.1x floor (a) would miss. Dev-val -0.00020 ± 0.00021 not judged
- Write-up UNCOMMITTED in model.md, learned.md (top of Win), embx.tsv (+learned column); diff sent to 53 (scratchpad embx-2253.diff of session 35e18589). Commit by path on 53's OK, tell 14
- COMMITTED f16367e (53 OK; dropped 'teammates mostly': no 2253Z ally/enemy split). Told 14 (push + offered next: ally-vs-enemy split on 2253Z, or distil E into profile terms; else close)
- STOP (bd, Jacob out of usage) after f16367e: nothing uncommitted of mine, no runs of mine on the gpu-box (all 2253Z embx runs ended exit 0). Idle; 14 still to answer on next step (ally/enemy split or distil E) when work resumes
