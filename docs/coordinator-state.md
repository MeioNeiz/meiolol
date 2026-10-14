# Coordinator state, 2026-10-14 (saved at stop)

Snapshot of the coordinator's handover notes when Jacob stopped all sessions (out of
usage). Agents: scratchpad/agents.tsv (sids) is in the e7ef341b scratchpad if it
survives; roster in docs/model-agents.md.

# Coordinator handover (meiolol-76 -> successor), 2026-10-13 ~23:55

You coordinate the meiolol modelling team for Jacob. Read first: docs/model-agents.md
(roster, kept current: edit and commit it by path on every change), nn-common.md here
(the shared brief every agent reads: goal, Hosts, Python, Reliability, noise floor),
docs/model.md, docs/learned.md, docs/lab-constraints.md.

## Jacob's rules and wishes (13 Oct)
- Big goal: best draft win predictor, measured honestly. Deployment: train heavy on the
  gpu-box, ship CPU-only models that pick out information (what a tower, synergy,
  counter, comp is worth). He wants creativity: our own variables (like team damage
  mix), combos, good and bad comps, which champions carry, novel approaches, many tests
- Model runs on the gpu-box ONLY, never the Mac (it slows his machine). lab-run refuses
  mac unless LAB_ALLOW_MAC=1 (4f60ffd). Mac: filtered tests only, no full test/ci except
  the coordinator's push
- Use as much gpu-box CPU+GPU as possible: slots (4 per resource, cddffa0), tuning by a0
- Python allowed in the lab (experiments, cross-checks); shipped code Zig (CLAUDE.md
  178e37e)
- Max 2 agents per tab, side by side (not stacked). A replacement goes where the old one
  was (cc-spawn --from <old pane> --right), then close the old pane
- Context: tell an agent at 30% to plan a handover, at 40% to do it. You too
- You push (every push deploys, pre-push runs ci). Agents commit by path, no push
- Test looks: only on your go, one per final model, pre-declared reading. None granted yet

## Tools
- Watcher: S=$(this dir); $S/ctxwatch.sh $(cut -f2 $S/agents.tsv) <your sid>
  run_in_background; exits on first crossing; message the agent, restart it.
  agents.tsv = name, session id, role: update on every handover
- Spawn: cc-spawn --tab / --from PANE --right --print-sid "Read BRIEF and do it."
  Names clash sometimes: rename-when-idle.sh PANE NAME
- Resume a closed agent: cc-spawn --from 957 --right --shell, then send
  `env -u CLAUDE_CODE_CHILD_SESSION -u CLAUDECODE -u CLAUDE_CODE_ENTRYPOINT
  CLAUDE_CODE_FORCE_SESSION_PERSISTENCE=1 claude --dangerously-skip-permissions
  --resume SID` (without it transcript saving is off). Never send-text into a pane Jacob
  may be typing in
- wezterm cli spawn hung for ~15 min under Mac load 37; check `timeout 20 wezterm cli
  spawn --pane-id <yours> --cwd /tmp -- true` before spawning
- pending-spawns.md: empty now
- Two sessions show clashing names: meiolol-0a [01815a] is meiolol-tests, meiolol-f1 is
  meiolol-research (renames queued); real lead modeller is meiolol-0a [101155]

## Team (see agents.tsv, model-agents.md)
0a [101155] lead nets (big def 10 seeds -0.00039 at floor; sealed seeds 11-20 running);
4b verifier (~28%, handover brief ready, hands over ~35%); f7 player nets (sealed seeds at
floor; next: calibration by history bucket, QuickSkill prior, base skill + offsets; adds
Row.player in rowsql via 4a); 30 scaling curves; ab embx (flat so far; close after its
gpu-box run); 35 [397394] set net (controls clean, sealed confirmation running); 4a data
(events.tsv done 703e2f8; next: gain-by-history slice + backfill cost; reviews f7's rows
change and repacks); 08 effects + CPU model (additive.zig, effects.zig; distillation from
0a's --fit-preds); research (f1 name; done 4 questions incl. GNN: no; finishing notes);
tests [01815a] (synth, health, golden 74cf241; planted sweeps running; Python cross-check
~03:00); a0 tooling (builds on gpu-box, slot tuning, gates, compare done 42ed9d6);
fd sweeps/placement (predictor scaling by slots; offering sweeps); c1 comp discovery
(comp_stats, ~200 candidates, FDR screen, sealed blocks 4-5); 61 carry and impact
(src/carry.zig); d8 tester (correcting LoLDraftAI write-up per 4b, then closes)

## Results that stand (milli-nats/game on folds; floor ~±0.5)
win-comp -0.57 (lopsided damage); 4-input average -0.61 ± 0.19; player experience
-2.5 to -3.8; random split flatters ratings by 2.7 ± 1.6 (4b, paired). At floor / not
established: big net, set net, pretrain d8, patch offsets, stacking beyond average, GBDT
loses to linear. GNN: research says no (player graph < 0.1 pt at 16 days)

## Open for you
- Push after each batch of finished work (last push ~23:55 incl. 25 commits)
- The 19 Oct weekly snapshot: pin decision, reruns listed in model.md Next steps
- Ask Jacob before: test looks, new agents beyond current count if the Mac is loaded

## Added at handover (~00:05)
- Pushed ade1d72 (25 commits), CI passed. Unpushed since: none of mine
- nn-common.md ends with "Recent findings that change how you run": keep it current;
  agents send findings to you and you append them (Jacob asked for shared learnings to
  help current runs)
- Decision for Jacob (from 4a): history backfill is out of reach on the personal key
  (~50M matches per month of history); champion mastery for every player is ~4 days of
  calls on unused platform buckets (career per-champion experience; small leak if read
  after the game). Production key changes all of this. Ask Jacob whether to run the
  mastery sweep
- 4b near handover (~28-35%); d8 closing after its LoLDraftAI correction; ab closing if
  its embx run is flat

## meiolol-bd (from 76), 13 Oct ~23:30
- Pushed 2b34be1 (c3bbe11 LDAI fix, 8efaa24, 7036c3f, roster). agents.tsv: d8 out, 58 in
- Mastery sweep: Jacob delegated, decided GO (4a): spare bucket capacity only, crawl
  throughput guard, fetch never used for games before it, internal only
- 58 plan approved (reader, ratings torch+sklearn, nets 10 seeds); baseline moves only
  via 4b; waits on a0 lab-run --python
- fd: sweep design A queued by default if 0a [101155] doesn't pick; a0 told gpu.slots=2
- tests [01815a] crossed 30%: told to plan handover
- Test looks granted by Jacob: 61 carry, one --final on 64ada94, readings (a) role gold vs
  team gold at 15/25, (b) champion x own lead 15/25, (c) champion x experience (~00:00 14 Oct)
- New agents: meiolol-state [701543] pane 1000 (owns state-export), meiolol-draftpath
  [36c2ab] pane 1001 (reads it); both named meiolol-41 until renamed. lab_main.zig: c1
  commits its hunks first, then state adds its line
- Research audit subagent running (research vs implementation); research f1 on
  live-win-probability, correlated-importance, draft-mediation
- 0a [101155] 33%, f7 31%: told to plan handover; 4b 30% hands over ~35%

## meiolol-bd state at 30% (14 Oct ~00:50 BST)
- NEW PIN: snap-20261013T2253Z on gpu-box (pack, seat_stats, mastery_pre); nn export +
  events by 4a pending (watch job: test -s .../nn/meta.json). When it lands: tell 04
  [79f90e] (references, A/A floor, big; pre-declared rule in progress-nn-lead.md),
  structured [3ec461] pane 1010 (win-comp spread, compcheck), 1d (additive model, best
  candidate -0.00129 vs ratings on 2055Z, cleared gates, with 33), 51 (player prior group
  -1.34 first look, confirm with sealed rule), 30 (scaling at new size), 61 (types),
  ab successor (embx pairs), c1 successor (comp screen). Verifier 33 [70ba19] owns the
  rebase gate (4b checklist: fb5a1644 scratchpad handover-verify.md); pin in model.md
  when 33 says items 1-5 pass. JACOB WANTS: "lmk when models ran on new data and how
  much better": report references vs 2055Z and 30's gap per doubling
- Standing goal (Jacob): more training data; re-pin at +50% games or weekly
  (model-agents.md Goals). 4a: mastery sweep after pin; re-measure history depth on pin
- Calibration T=0.8 code pushed; 1d exports draft-model.json on new pin then you push
- gpu-box: reserve 5 cores + 3 cpu slots x5 + FIFO fast lane (a0/fd/1b); tooling
  successor meiolol-tooling [904e99] pane 1011 re-timing slots
- Name clashes: two meiolol-04 (lead [79f90e] pane 1002, tooling [904e99] 1011), two
  meiolol-33 (verifier [70ba19] 1005, structured [3ec461] 1010), two meiolol-41 (state
  [701543] 1000, draftpath [36c2ab] 1001); renames queued (rename-when-idle.sh)
- Context: told to plan: c1, 61, 4a (34%), ab 29%. Successors registered in agents.tsv
- Research: audit done (little dropped; items assigned); f1 research answered 3 new Qs
- Unpushed: ~25 commits; push when a batch is done (CI on Mac)

## meiolol-bd handover at 40% (14 Oct ~02:00 BST) - READ THIS SECTION FIRST
Protocol (Jacob, final; roster model-agents.md Goals):
- Training always uses every game; test reflects the training sources: ONE global time
  cut over all platforms, test = newest 15%, dev-val = next 10% (no selection window),
  5 forward folds below; finals train on all before test; shipped exports on everything
  after the look. No EUW slice now; a future region model = global model fine-tuned on
  that region with its own test (73 adds an optional region param to the shared split)
- Re-pin at +50% games or weekly; 73 owns crawl volume/coverage
In flight:
- 73 [pane 1013] re-cutting snap-20261013T2253Z per 33's split-rules.md (33 scratchpad)
  + seat_stats union (done, interim pack built). Shared split function across eval.split,
  harness, nnexport, effects, winnet, playernet, compcheck, comps, randsplit. Pings all
  holders once when done. EVERY earlier 2253Z run is void (discarded unseen)
- Holders waiting on 73: 04 [79f90e] (whole rebase chain; reports accuracy too),
  structured (win-comp), 1d (effects A/B/C/T + draft export with T refit, then PUSH and
  lab-push), 51 (prior+duo, sealed), 64 (embx), 94 (comps), state [701543], draftpath
  [36c2ab]. 33 runs pincheck + blockcheck, then says gate passed -> pin text in model.md
- JACOB WAITING ON: "how much better is accuracy with extra data". Answer = 30's learning
  curves (told to run ratings/net fits now on 2253Z, report log loss + accuracy per size,
  gain per doubling, projection 2x/4x; ETA pending) + 04's references after re-cut.
  Void pre-gate hint: small net went +0.66 -> -0.21 vs ratings with ~1.7x fit data;
  ratings accuracy on 2055Z folds 52.9 ± 0.5%
- gpu-box sleep: root cause fixed (3e686d6, pushed); AC sleep timeout reads 5 h (asked
  Jacob if he changed it, no answer). CPU is bottleneck; tooling [904e99] re-timing
- Context: draftpath 30% (told), others below; handed-over agents all registered
Results worth knowing: additive model (1d) -1.29 ± 0.54 vs ratings on 2055Z (cleared,
not established over win-comp); player prior group (51) -1.34 first look; top-vs-top
matchup 2.5 pp; set net confirmed barely; embx not confirmed by 0.00001; big net level
with ratings; PyTorch agrees with Zig on ratings/small/big
Background jobs of mine end with me: restart ctxwatch.sh (agents.tsv) and any
rename-when-idle jobs still needed (1000 state, 1001 draftpath, 1004 tests, 1011 tooling)
- Draftpath results (2055Z dev, to 33 for audit): draft alone -0.0011 nats/game but given
  the state -0.006 (5 min) to -0.016/-0.018 (15-30): 15x more once state known, no fade;
  draft sets 6-7% of lane gold leads, 20% of kill pace; mediation: early champions give
  their lead back (indirect vs direct r -0.8); no draft-specific comebacks. Tell Jacob

## meiolol-14 [8efacb] (from bd), 14 Oct ~01:10 BST
- Own sid 579dda6c-5b02-4b6f-95c6-dc1e7c9e5134; ctxwatch + renames 1000/1001/1011 restarted
- 30: 2253Z curves ETA ~01:40-01:50 BST -> report to Jacob. Big-net config check (1954Z):
  config explains ~0.0002, big stays behind ratings at top size
- st1 (fd, netd on 2253Z old split): told fd + 41 [701543] stop, void unseen, requeue after
  73's ping; pn1 waits too. fd now reports to 14
- Unpushed to include in next push: bd51189, dc2f3dc
- Slots: approved tooling [904e99] (a) gpu.slots 3 now, (b) cpu 4x4 reserve 4 + memory gate;
  told fd. Tooling reports to 14, confirms when live
- initLoss gate (bc50c0e): asked 51 playernet, structured setnet, 04 [79f90e] winnet,
  64 pretrain to hook it. Unpushed adds: 37a9141, bc50c0e, 8232eee
- Pushed c4e8077 (25 commits). Unpushed since: 0723d43 (memory gate), 1c0629a roster, others
- fd -> meiolol-37 [7c5b0d73] pane 1018 (sweeps). Draftpath -> pane 1017 [cc1fb5]
  (97210f04), renamed meiolol-draftpath; readings pre-declared with 33
- 33 at 30%: brief at its scratchpad handover-verify.md (69ca1cb7.../scratchpad); finishes
  gate after 73's ping if it can
- Asked tooling: memory gate's 20-min go-anyway only if MemAvailable >= half the peak
- Scaling answer given to Jacob (~01:35): +0.55 pp/doubling (1954Z, 2055Z), flattening not
  established, 4x ~+0.5-1.1 pp. 2253Z curve points WITHDRAWN (old split, overlap new test);
  30 reruns on 73's ping, then report to Jacob. 33's exposure conditions: count beside pin
  in model.md; no model choice cites them; test looks on ratings/small/resid/big also
  minus exposed games
- Decided for 73: in-game tools + winchance to shared split, no platform default; region
  param kept, default off, region model only
- 73 re-cut 2253Z landed + pushed 0c3e486. 33 gate items 1-4 PASS; item 5 waits on 04's
  rb-ref-wr/wc + structured's win-comp. Exclusion list: 1,885 2055Z-looked games, kept in
  test, report both; 30's curves 0 exposure; 1954Z never looked. Asked 73: SNAP/
  test-exclude.tsv, --final reports both in harness, pin text; then in-game split + region
- 30 rerunning 2253Z curves on re-cut -> Jacob; then hands over with curvefit plan
  (approved: n_eff, patch decay, tau^2 smoothing, embedding blend lab-only)
- GATE 2253Z re-cut PASSED for ratings-paired (33, ~01:45): told 04, 51, 30, draftpath,
  state. Win-comp holders (1d H1, 64, 94, structured, 04 rb-ref-wc/rb-big-wc) unread
  until 33's successor checks rb-ref-wc -> then tell them. 33 handing over now
- Ratings 2253Z folds 0.68901; small 5-seed ens -0.34 ± 0.14 mnats, resid -0.17 ± 0.08
- (bd, after handover, covering while 14 waited on Jacob ~6 h): pushed e061f27 (79
  commits); 51 -> meiolol-74 (pane 1024), player B1/B2 parked as scratchpad diff
  rowsql-skill-rel.diff v2 until the re-pin (ping 74 then); 1d's additive model PASSED on
  2253Z (-0.00115 vs win-comp), estimator fix then shipped switch; 51's history means
  passed (53.7 -> 55.5 -> 56.1% folds)
