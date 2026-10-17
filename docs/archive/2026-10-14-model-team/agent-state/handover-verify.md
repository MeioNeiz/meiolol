# Handover: meiolol verifier (meiolol-33, from 4b)

Coordinator: meiolol-14 (took over from bd). Report the 2253Z gate to 14, pass or fail,
as soon as decided. Older rules (gpu-box only, floor rule, gains tool, commit by path,
never push, never rerun a test look, nothing to learned.md before audit from run dirs):
4b's brief /private/tmp/claude-501/-Users-jacobmaschler-personal-meiolol/fb5a1644-d228-4911-862b-0bb55a500fb6/scratchpad/handover-verify.md
Running log: verifier-notes.md beside this file (newest at the bottom).
Shared briefs: /private/tmp/claude-501/-Users-jacobmaschler-personal-meiolol/e7ef341b-8499-41da-a5fc-b957ce24a790/scratchpad/
(nn-common.md, progress-*.md, agents.tsv = name -> role).

## Protocol on snap-20261013T2253Z (Jacob's final, via bd)
Global time cut, all platforms, NO EUW slice anywhere (per-platform = description only):
test = newest 15% of played games, dev-val = next 10%, folds = 5 forward blocks below.
Exact rules I gave 73: split-rules.md (this dir). Shared harness split function called by
every tool + eval.split; nn split codes keep numbers (0 dev_old, 1-5 folds, 6 dev_val,
10 test; 7-9 empty); meta.json gets test_cut, dev_cut. Fits strictly before each
window's cut; any --final before T; exports on everything after the look.
Every 2253Z run on the old cut is discarded unseen. Seat_stats union with 2055Z in the
same repack (first cut had 38% coverage in dev_old; union >= 99.97%, 1.6M overlapping
seats byte-identical; ~/ml/analysis/ssfill-33.py).

## STATE (meiolol-53, 14 Oct ~01:5x): GATE COMPLETE, reported to 14. Now: audit pre-declared
rules as owners send dirs; 04 test look cleared (3c6c6c8 + rule predecl-04-testlook.*), awaits 14/Jacob go.
Pending: aa-big rN cand vs rb-aa-small rN equality when rb-aa-small ends.

## At re-pin (next snapshot)
- Review 51's rowsql-skill-rel.diff (e7ef341b scratchpad) against its accepted conditions (verifier-notes)
- 04's big test look still awaits 14/Jacob's go (rule predecl-04-testlook.*, additive 0.21)

## FIRST (successor) [DONE by 53]
Gate reported to 14 as PASS for ratings-paired runs (items 1-4 + ratings part of 5).
Remaining gate step: win-comp reference. When 20261014T003341Z-rb-ref-wc ends (was queued;
a bg watch bu522014n may still be running in my session, ignore it), run:
  ssh gpu-box '~/ml/.venv/bin/python ~/ml/analysis/blockcheck-33.py ~/ml/snaps/snap-20261013T2253Z
  ~/ml/runs/20261014T003341Z-rb-ref-wc/small/games-win-comp.tsv ~/ml/runs/20261014T003341Z-rb-ref-wc/resid/games-win-comp.tsv
  [+ meiolol-structured's games-win-comp.tsv, + 1d's e53-B0 cand file]'
and seed spread of small/resid vs win-comp (python snippet in my transcript; or pair.awk on
the Mac per seed column). Then tell 14 the win-comp part passed: that releases 1d (H1/H2 read
together), 64 embx, 94 comps, 04 rb-big-wc, structured. Then audit each pre-declared rule.

## Gate items (state at handover)
RE-CUT DONE (73, 85fd62a, pack d42d80d): items 1-4 PASS (pincheck-2253Z-recut.txt), interim sent
to 14. ONLY item 5 left: 04's 20261014T002905Z-rb-ref-wr (small/ resid/ games-win-ratings.tsv),
20261014T003341Z-rb-ref-wc (games-win-comp.tsv), also 003419Z-rb-big-wr cand; NOT sealed
003438Z-rb-aa-small, 003501Z-rb-aa-big, 003523Z-rb-big-wr-s11, 003542Z-rb-big-wc; plus
meiolol-structured's win-comp; blockcheck them + nnsets blocks; then final report to 14.
Exclusion list ~/ml/analysis/test-exclude-2253Z.tsv (1,885); 73 to copy to SNAP/test-exclude.tsv.
Draftpath agent = meiolol-draftpath.
WAITING on meiolol-73 (DATA, 4a's successor): commit with the shared split function,
re-cut + seat_stats union + repack + nn-export; it will state the split.u8 code table.
1. Pin files: pincheck. First cut: manifest/ids/mastery OK, seat_stats FAIL (fix above)
2. Settled (played games, no timeline filter)
3. Test: pincheck global branch (T = start at index n - round(0.15n), every game >= T is
   test, 0 looks). Note where 2055Z's 10,759 test games land (pincheck prints it)
4. Folds/dev-val: pincheck (D at n - round(0.25n), dev_val = [D, T), folds in bounds,
   bound 0 = median dev-visible start, codes 7-9 empty) + review 73's code: grep Zig
   tools for hard-coded split codes, EUW, Phase .select, harness.cuts(…, eu); nnexport
   test asserts bounds equal across nnexport/harness/win-comp/compcheck.
   py/xcheck/nnsets.py reviewed: codes only, fine if codes keep numbers
5. References: 04's rb-ref-wr, rb-ref-wc (and rb-big-wr cand), meiolol-structured's
   win-comp rescore: blockcheck (blocks = nn/split.u8 by match id; same-name cand files
   equal across runs), seed spread. Read refs only, never sealed statistics.
Then report to 14; owners may read their blind runs only after that.

## Commands (gpu-box, ~/ml/.venv/bin/python; scripts also in this dir)
- ~/ml/analysis/pincheck-33.py ~/ml/snaps/snap-20261013T2253Z ~/ml/snaps/snap-20261012T2055Z
- ~/ml/analysis/blockcheck-33.py SNAP run1/out/games-win-ratings.tsv run2/.../games-win-ratings.tsv ...
- Mac pairing: awk -F'\t' -f conf/pair.awk CAND.tsv MODEL.tsv (folds pooled ± 95%,
  1.6x bound, per block, dev); zig-out/bin/meiolol-lab gains UNITS A B (2055Z units)
- zsh: no word splitting of $x, write args out

## Pre-declared 2253Z rules on file (copies predecl-*.md here); all run blind until gate
- 04 [79f90e]: big net sealed seeds 11-20 vs ratings < 0 by > 1.3x half AND mean over
  rb-aa-big r1-4 (ens-cand) < 0; dev-val reported. predecl-04-*
- 51: prior+duo beyond win-exp, seeds 4-6, A/B, resample 1,2; mean+1.6h<0, both resample
  means<0, >=4/5 blocks; pfeat control vs cand not < -0.5 else void; may build at 73's
  commit (accepted deviation). predecl-51-*
- 1d: effects H1 full-win-comp, H2 full-mains-mix; full + resample 1,2; 1.6x + both
  resample<0; C voids only on gain; full/mains-mix preds equal A_n vs B_n. predecl-1d-*
- 64: win-embx (a) sealed E 4-6 vs win-comp 1.6x (b) vs sealed shuffled E < 0 (c) one
  resample draw < 0 ("sealed seeds and one resample draw agree"); folds only
- 94: comps screen blocks 1-3 BH over 244, sealed 4-5 + dev-val minus --seen, Holm 0.05,
  (b) one-sided, tank x pen two-sided, permuted screen void at 2+ passes; mix row =
  replication. predecl-94-*
- 30 [cc1fb5] draftpath: Q1 draft|state min15 folds <= -0.008, CI excl 0, >=4/5,
  dev CI excl 0; controls shuffle + shuffle-within void on gain. Q3 indirect 10/14/20
  two legs, branches (a) both - (b) both + (c) not detected < B (d) unresolved.
  predecl-30-*

## Done this session (all sent; details in verifier-notes.md)
35 set net sealed: A confirmed barely (-0.37 ± 0.21, honest 0.15-0.4), B not;
61 carry: cleared with wording; carry-types: own-gold x type not established (2253Z only);
1d additive: beats ratings -1.29 ± 0.54 (3/4 is mix), not established over win-comp;
c1/94 comps: cleared with wording (mix not truly sealed), line af3a971;
64 embx 2055Z sealed: not confirmed (-0.371 ± 0.242, bound +0.016);
41/30 draftpath 2055Z: no leak; Q1 holds (shuffle +0.15 ± 0.24), Q2 platform in draft
gain, Q3 folds vs dev-val disagree (unresolved), Q4 top-lane under floor;
4a history line: 1954Z leg cleared (key 4b83f38f matched a0's rebuild).
a0 key verifies: /private/tmp/claude-501/-Users-jacobmaschler-personal-meiolol/b829d9f1-7438-4cfa-a13f-a213a5f1a0e0/scratchpad/v0.out, v1.out

## Pending audits after the gate
73 follow-up commit: in-game tools + winchance on shared 15% split, no --test-platform defaults; region param default off and labelled (14).

Every pre-declared rule above, from games files, when owners send dirs. Draftpath Q1-Q4
on 2253Z. model.md pin text (T, D, bounds, counts and patches per window, where 2055Z's
test landed, leak note, Jacob's no-EUW call): coordinator or me once the gate passes.

Test exposure (14): 30 learning curves on 2253Z old split before 85fd62a; overlap count by match id vs new split.tsv pending (30); record beside pin; test looks for ratings/small/resid/big also minus exposed games.
Exposure check: ssh gpu-box ~/ml/analysis/exposure-33.sh ~/ml/snaps/snap-20261013T2253Z (after the re-cut split.tsv), compare with 30s count.
