# progress: comp discovery (meiolol-c1)

Brief: scratchpad/brief-comps.md. Plan sent to meiolol-76 13 Oct (late evening).
Design: residual screen (observed win - win-ratings, blue minus red per game), win-comp's
5 fold blocks; SCREEN = blocks 1-3, SEALED = blocks 4-5 + dev-val (open once, survivor
list only). BH FDR over all candidates; sign-flip shuffle control; MDE via plant:mix.
Tools: src/lab/compstats.zig (SNAP/comp_stats.tsv), src/lab/comps.zig (screen).

## Runs
| id | question | status |
| --- | --- | --- |

## Findings

## Log
- 3ab7299: compstats.zig committed; run 20261013T222121Z-comp-stats wrote comp_stats.tsv
  (2,303,750 seats) and comp_teams.tsv (460,750 teams) on gpu-box pinned snap.
  soloTurretsLategame absent = 0 (never 0 in data).
- comps.zig (uncommitted in main tree; builds from scratchpad/tree, a git copy of HEAD +
  my files: scratchpad/chk.sh copies and Debug-builds; lab-run from that tree with
  --commit SHA). main tree has others' broken nnexport.zig/objectives.zig edits.
- compcheck.zig: Source and offset made pub (uncommitted).
- Carry vars: meiolol-61 sends per-fold table (fold 1-5, dev; champion; role; rows;
  cols). Real screen waits for it (one look, carry in the FDR count).
- Fold bounds (snap-20261012T2055Z): 1791207975222 1791343605806 1791381476557
  1791412237339 1791449610397; dev cut 1791476584095; select 1791586166991.
- Controls before the real look: plant mix=-3 (run 20261013T223736Z-comps-plant-mix3),
  then plant at smaller sizes, permuted profiles (--permute-profiles 1).
- 3df16c6: comps.zig committed (lab_main hunks too; told bd and 41). Coordinator is now
  meiolol-bd.
- Plant mix=-3 (seed 1, 20261013T223736Z): mix z -5.9 (recovered -1.26 pp/team sd ~ 59%
  of planted per diff sd), BH passes 5 (others mix proxies: archetype 5 enchanters, armour
  pen, lethality) -> added "beside mix" column. Shuffles 0 passes.
- Plant mix=-1.5 (seed 2): mix not detected (-0.15 ± 0.42), so MDE ~1 pp per team sd.
  Same run exposed rare-flag bug (carry none-above-median in 2 games, z 175): guard
  min_differing = 200 games in slope and ols.
- Carry: ~/ml/comps/carry3.tsv on gpu-box = 61's table cut to leverage10, leverage25,
  scaling (chosen before any look). NOTE: permuted run doesn't permute carry: don't read
  carry rows there.
- Running on 3df16c6: comps-permuted, comps-plant-mix2p25. Real screen after.
- e6588c1: --export-teams (teams.tsv per scored team per block, for meiolol-41 [36c2ab]
  draftpath). Run comps-export-teams queued.

## Pre-declared (14 Oct ~00:10, before the real screen look)
Real screen: `comps SNAP --screen --shuffles 20 --carry ~/ml/comps/carry3.tsv` on the pinned
snap, built e6588c1 or later with comps.zig screen unchanged.
Sealed list = (a) screen BH q 0.05 passes, not family "control", same sign in >= 2 of 3
blocks; (b) every coaching hypothesis candidate (hyp != 0: 21 crosses + specials with a
predicted sign), whatever the screen says. Sealed reading: Holm over the list at 0.05;
(a) items also need |beside-mix z| >= 2 on sealed to count as more than a mix proxy.
Control passes (sum family) are reported as ratings misfit, not comp effects.

## Controls done (3df16c6, snap-20261012T2055Z, 252 candidates, 26,611 screen games)
- Permuted profiles (20261013T230807Z-comps-permuted): 0 BH passes at q 0.05 and 0.10.
- Shuffled residuals (20 shuffles, same run): 2 passes in 2 of 20 shuffles (FWER ~10%,
  BH nominal 5%), largest |z| 3.87.
- Plant mix -2.25 (seed 3, 20261013T230832Z): lopsided z -4.6, mix -4.4, magic_hi -3.5
  pass; proxy max magic_dpm passes (beside mix 0.47). Plant -1.5: missed. Plant -3: z -5.9.
  MDE ~2 pp per sd of the blue-minus-red difference (~1 pp per team sd; flags at 10%
  prevalence ~3 pp).
- Team export for 41 done: ~/ml/runs/20261013T230628Z-comps-export-teams/teams.tsv.
- Real screen queued: 20261013T231749Z-comps-screen (e6588c1).
- Real screen read (20261013T231749Z): 7 BH q05 passes (mix, lopsided, AD x armour, magic_lo, ranged4, 1+ magic_pen, 2+ immob_kills); 12 at q10; shuffles 3/20 with any pass. Sealed list (27) at ~/ml/comps/sealed-list.txt and scratchpad/comps-sealed-list.txt.

## Sealed result and write-up (14 Oct)
- Confirm 20261013T233834Z-comps-confirm: Holm over 27 -> only mix (-0.89 ± 0.42 pp/team
  sd, z -4.13). AD x armour -0.30 (z -1.4), ranged4 +0.49 (flipped), 2+ immob_kills +0.75
  (z 1.5): not confirmed. magic_pen flag 1.25 (z 2.4) but beside mix 0.51: proxy. Best
  hypothesis: tankiness x their pen items +0.65 (z 3.0, opposite sign; not Holm).
  Layer: ratings+mix -0.00028 ± 0.00042 sealed; survivors worse.
- Joint OLS column empty: 3 degenerate traits (no_objective, split x wave, siege x wave:
  NaN x) drop every row in ols(); fix by skipping all-NaN columns. 10 degenerate
  candidates in total (wave_burst traits: x all 0; 1+ top vision/epic: every team has).
- Write-up committed 0a6a424 (docs/model.md "### Comp discovery", docs/nn-results/comps.tsv).
- Sent: verifier meiolol-33 (audit), effects meiolol-1d, structured (35 -> meiolol-structured
  [3ec461]), draftpath meiolol-41 [36c2ab] has teams.tsv. Not yet: meiolol-state.
- Next for successor: 33's audit replies; learned.md line only after it; rerun on
  snap-20261013T2253Z (comp-stats, 61's carry table on its cuts, same rules); fix
  degenerate traits first (declare the fix before the rerun's look).

## meiolol-94 (from c1), 14 Oct
- Audit meiolol-33: CLEARED with wording (mix not a sealed find, block split 4/5/dev
  -1.14/-1.29/-0.13, no fight claim, plant builds, 12 NaN rows, detection sizes in true
  units). Commits 417b87b, af3a971, faacca0: learned.md Win line "2026-10-14: Screening
  252 team traits", model.md wording, comps.tsv learned column. Not pushed (bd pushes).
- meiolol-state: not reachable by that name (agents.tsv has it, ListAgents doesn't);
  result not sent yet. Retry.
- 379a751 degenerate fix (declared here before any 2253Z look): V.wave_burst dropped
  (twentyMinionsIn3SecondsCount >0 in ~1 of 200k seats); Agg.wave = sum z cs_pm
  (minions per minute, in-role z) -> split x wave, siege x wave and archetype clustering
  use it; flags dropped: 1+/2+ top wave_burst, vision_pm, epic_pm (role-determined);
  no_objective = no seat with role z >= 1 in epic_pm, dragon_td or herald_td; confirm's
  joint OLS leaves out columns whose sealed slope is NaN. Candidates 252 -> 244 (with
  12 carry).
- a0d6e42: `--confirm --seen IDS`: match ids left out of sealed blocks.
  ~/ml/comps/seen-2055Z-sealed.txt = 2055Z nn splits fold4, fold5, dev_val (26,606 ids,
  superset of the 26,242 scored). Overlap with 2253Z: fold4 967, fold5 2555, dev_val
  2372 (5,894); fold1-3 hold 20,712 of them (fine: screen).
- 2253Z cuts (nn/split.u8): folds 1791399920616 1791440035991 1791471516870
  1791503426611 1791538594699; dev 1791565305815; select 1791667302145 (check vs the
  comps log's first line). Sent to 61 for carry table on 2253Z.

## Pre-declared for 2253Z (14 Oct ~01:15 BST, before any 2253Z comps look)
Build: a0d6e42 or later with comps.zig screen/trait code unchanged; -Dcand win-ratings.
Real screen: `comps SNAP --screen --shuffles 20 --carry ~/ml/comps/carry3-2253Z.tsv`
(61's 2253Z table cut to leverage10, leverage25, scaling), --res cpu, one run.
Controls first or beside: --permute-profiles 1 (expect ~0 passes).
Sealed list = (a) screen BH q 0.05 passes, family not "control", same sign in >= 2 of 3
blocks; (b) every candidate with hyp != 0; (c) named from 2055Z whatever the screen says:
mix, our AD share x their armour lean, ranged4, 2+ top immob_kills, 1+ top magic_pen,
our tankiness x their penetration items (near-misses and the opposite-sign hypothesis).
Confirm: `comps SNAP --confirm LIST --carry ... --seen ~/ml/comps/seen-2055Z-sealed.txt`.
Decision: Holm over the list at 0.05 on the unseen sealed games; (a) and (c) non-mix
items also need |beside-mix z| >= 2. tankiness x pen counts in either sign (two-sided
Holm), reported as opposite to theory if positive. The mix row is a replication on
fresh games (not a discovery). Also report the same confirm without --seen beside it
(not used for decisions). If screen and confirm need code changes after the look, they
are new runs, declared here first.
- Carry 2253Z: 61's ~/ml/runs/20261013T234133Z-carry-types-2253/carry-folds.tsv (f694030,
  cuts match) cut to ~/ml/comps/carry3-2253Z.tsv (fold, champion, role, rows,
  leverage10, leverage25, scaling). 61 handing over; successor owns carry.
- Runs 2253Z: 20261013T235230Z-comp-stats-2253Z (379a751) queued. Next, on a0d6e42:
  comps-permuted-2253Z, comps-screen-2253Z, comps-export-teams-2253Z (for draftpath 41
  [36c2ab] and state 41 [701543]). Then sealed list, then confirm with --seen.
- HOLD (bd, 14 Oct): seat stats cover 77.5% of 2253Z until meiolol-73's repack (33's
  gate). comp-stats-2253Z stopped while queued (never ran, nothing seen). Restart all
  2253Z runs after bd's go: comp-stats, then permuted, screen, export-teams.
- GO (bd): start when meiolol-73 pings the 2253Z repack done. comps fits its own
  ratings offset (no 04 preds), so the declared commit a0d6e42 stands. Results stay
  unread until 33's gate passes.

## Amended pre-declaration for 2253Z (14 Oct, protocol final via 33/bd; before any look)
Protocol: test = newest 15% of all played games; dev-val = next 10% (all platforms, no
EUW slice, no selection window); folds = 5 forward blocks below dev-val. Build: 73's
post-repack commit (shared split function) plus my comps commits (379a751, a0d6e42),
with any comps.zig change needed to use that split declared here before the run. Screen
= blocks 1-3; sealed = blocks 4-5 + dev-val (this dev-val). Cuts printed by comps' log
line 1 are the record; carry table rebuilt on those cuts (61's successor), cut to
leverage10, leverage25, scaling. Everything else as declared above: sealed list (a)+(b)+
(c), --seen 2055Z sealed ids, Holm over the list on unseen sealed games, beside-mix z>=2
for (a)/(c) non-mix, mix row = replication. Controls: permuted profiles. Runs only after
73's repack ping; results unread until 33's gate passes.
- 61 closed with no carry successor: I rebuild the carry fold table myself after 73's
  commit: `lab-run start gpu-box carry-folds-2253Z --meiolol --commit <73's+mine> --res
  cpu -- carry --data ~/ml/snaps/snap-20261013T2253Z --platform all --fold-table
  carry-folds.tsv` (61's run 20261013T234133Z-carry-types-2253 also wrote --type-table
  and --table; check carry.md's cuts = comps' log line 1), then cut to carry3-2253Z.tsv.
  Rule sent to 33 for sign-off.
Clarifications (33 accepted the rule with these, 14 Oct, before any run):
1. Sidedness: (b) items one-sided in their predicted direction (p = Phi(z * -hyp)...
   i.e. small when z has the predicted sign), except tankiness x pen, which is also in
   (c) and stays two-sided; everything else two-sided. Holm over those p-values
   (computed from confirm.tsv's z by script, kept in the run dir).
2. Control void: the permuted-profile screen voids the real screen if it has 2+ BH passes
   at q 0.05; the permuted run gets no sealed reading.
3. Report unseen sealed games per block after --seen, and where 2055Z's sealed ids land
   on the new cut (fit/screen/sealed counts). Screen games overlap 2055Z's sealed look:
   noted, fine for a screen.
Build only after 73's repack with the 2055Z union (seat_stats coverage).
- 73's re-cut landed (85fd62a: comps takes c.bounds, dev-val hi = c.test_). Cuts: T
  1791795719197, D 1791741249959, folds 1791526007256 1791574830751 1791628507185
  1791670472926 1791711141905. Every earlier 2253Z run void. Coordinator now meiolol-14.
- Pin commit 0c3e486 (HEAD, includes 85fd62a, 379a751, a0d6e42). Runs:
  20261014T003526Z-carry-folds-2253Z (meiolol carry, fold table), 20261014T003545Z-
  comp-stats-2253Z. Next: carry3-2253Z.tsv, then permuted + screen + export-teams.
- 2055Z sealed ids on the new cut: dev_old 21,205, fold1 4,146, fold2 1,255; 0 in
  folds 4-5 or dev_val: --seen drops nothing, the 2253Z sealed blocks are all unseen.
  Screen blocks 1-2 hold 5,401 of them (noted, fine for a screen).
- draftpath (meiolol-draftpath) wants export-teams on 2253Z: ping it with the run dir.
- Done: carry-folds-2253Z (cuts = 73's), comp-stats-2253Z (303,456 of 372,340 games'
  summaries, 81.5%). carry3-2253Z.tsv rebuilt. Started on 0c3e486:
  20261014T005415Z-comps-permuted-2253Z (shuffles 0), 20261014T005437Z-comps-screen-
  2253Z (20 shuffles), 20261014T005458Z-comps-export-teams-2253Z. Verifier now
  meiolol-53 (33 handed over); gate inputs sent. Results unread until its gate.
- GATE PASSED (meiolol-53, 14 Oct). comp-stats coverage by window for the write-up:
  dev_old 59.6%, folds 1-3 ~89%, fold4 93.5%, fold5 95.6%, dev_val 99.7%, test 100%;
  RU 1%, TR1 47%, rest 73-87%; missing games no outcome or duration difference. --seen
  drops nothing: report one sealed number ("unseen sealed = all sealed"). Send 53 run
  dirs (screen, permuted, confirm) + Holm script after the confirm.
- READ (after 53's gate): permuted 20261014T005415Z: 0 BH passes q05/q10 -> screen not
  void. Screen 20261014T005437Z: 244 cands, 80,625 games, 15 passes q05 (15 at q10);
  shuffles 0 passes q05 in 20, largest |z| 3.66. 1 NaN row (carry none above median
  leverage10). Sealed list by script (data/runs/<screen>/sealed-list.txt,
  sealed-list-src.tsv; ~/ml/comps/sealed-list-2253Z.txt): a 15, b 24, c 6 -> 32 names.
- Sidedness pinned before the confirm (stricter reading of clarification 1): one-sided
  only for names in (b) alone; names also in (a) or (c) two-sided.
- Confirm 20261014T005906Z-comps-confirm-2253Z (0c3e486; 89,584 sealed games, 0 seen):
  holm.py + holm.tsv in its run dir (Mac data/runs). Confirmed by rule (Holm 0.05, beside
  mix |z|>=2 for a/c): mix -1.06 ± 0.23 pp/sd (z -9.1, replication), lopsided -2.99 ±
  0.78 pp (beside mix z -3.9), magic_hi -2.14 ± 0.93 (beside -4.1), AD share x their
  armour lean -0.63 ± 0.23 pp/sd (z -5.3, theory sign), AP share x their armour lean
  +0.56 (z 4.8, theory sign; near mirror of AD x armour), tankiness x their pen items
  +0.62 (z 5.2, OPPOSITE to theory, two-sided as declared), sustain x their poke -0.58
  (z -4.9, OPPOSITE to theory; in a so two-sided). Holm pass but mix proxy: magic_lo,
  phys_hi, max magic_dpm, max magic_pen, 1+ magic_pen. Not: melee4, ranged4, 2+
  immob_kills, every other hypothesis. Range x engage = -(engage x range) exactly (z
  ±3.17: our poke into their engage +0.37, opposite to both one-sided hypotheses, not
  confirmable under the rule). Joint column NaN again: exact collinearity (lopsided =
  magic_lo + magic_hi; range x engage = -engage x range) -> SingularMatrix; not in the
  decision rule; fix later (drop exact duplicates). Layer (sealed, nats/game): +mix vs
  ratings -0.00046 ± 0.00022; +31 list terms + mix vs +mix -0.00034 ± 0.00025 (under
  the ~0.0005 noise floor: needs resample before any claim). Sent to 53 for audit.
- 53 audit: CLEARED with one change: sustain x poke NOT confirmed (two-sided pin came
  after the screen; it's a lead). Three findings beside mix: magic 60%+ (= lopsided),
  damage type into armour (AD/AP x armour lean, one mirrored), tankiness x pen (+,
  opposite theory). Write-up drafted uncommitted in model.md/learned.md/comps.tsv; diff
  sent to 53 (scratchpad 23b82ba3.../comps-2253Z-writeup.diff). Commit after its OK.
- Then: tell state 41 [701543], draftpath, meiolol-1d (CPU model), meiolol-structured,
  coordinator meiolol-14: candidate terms mix, magic 60%+, AD share x armour lean,
  tankiness x pen. Code todo: drop exact-duplicate candidates (range x engage vs engage
  x range) before building the list; joint OLS then non-singular.
- COMMITTED 52b49b5 (53's two fixes applied: poke x engage screen z -0.04, sealed-only;
  27,552 sealed games were in 2055Z test/selection, never used by comps). Carried 04's
  noise-floor hunk. Sent: 04, 1d, structured, draftpath, coordinator meiolol-14 (asked
  to forward to meiolol-state, whose pane shows a shell). Open: code todo (drop exact
  duplicate candidates); next task from 14.
- e6f582e: export-teams adds phys_share, armour_lean, pen (appended). Run
  20261014T011109Z-comps-export-teams-2253Z-b (first 17 cols identical to 005458Z).
  Sent to 1d (tests the 3 terms pre-declared after its variance fix); draftpath told
  magic_share is raw 0-1 (60%+ = 6.5% of teams).
