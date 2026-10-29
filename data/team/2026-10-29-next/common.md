# Next (29 Oct): coordinator meiolol-4b, 3 workers

Goal: finish the legacy UI removal (data/team/2026-10-28-legacy/common.md stays its
rulebook and ownership), then plan.md "Now" by harm, then what Riot's reviewers see, then
what brings players back. One team: Jacob's call (29 Oct), 4b took over from 6a.

## Jacob's calls (29 Oct)
- One team: 4b coordinates the legacy run and this one; 03 and 3a finish their legacy
  lanes first, then take the next lanes below; one new worker (W3)
- Two sessions per tab: 4b + W3 in one tab, 03 + 3a in theirs
- Legacy calls (28 Oct) still hold: legacy common.md "Jacob's calls"
- C01 reboots are fine; never reboot, restart or change Megatron (or other hosts at Ethan's)

- 29 Oct 13:5x (Jacob: two more agents): W4 meiolol-92 (pane 1643) and W5 meiolol-c6
  (pane 1644), one new tab; briefs brief-w4.md, brief-w5.md

## Rules
- Messages: "done: <sha> <one line>", "blocked: <why>, <path>", "question: <path>";
  details in notes/<you>.md. Coordinator reads commits; findings come back as a message,
  fixed in a follow-up, don't stop for it
- Shared checkout: edit only your own files; commit by path (deploy/commit.sh), push the
  tested sha with deploy/push.sh <sha> (run_in_background), never wait-deployed. Pages
  are checked on deploy/dev.sh (localhost:8080). Tree red with others' WIP: commit from a
  clean worktree (legacy notes/coord.md "How")
- Context: a hook reminds at 25% and 33%. Hand over at a natural break (step committed,
  state in notes/<you>.md) with `cc-handover --new`; the successor keeps the session name,
  no rename message. A successor reads its notes file and only the docs its next step
  needs
- Never rewake a finished subagent (a hook blocks it); spawn a fresh one or do it yourself
- Plan docs say what is true now: update the step's plan doc as it lands

## Ownership
- Coordinator (meiolol-4b): legacy coordination (legacy notes/coord.md), lane 0
  leftovers, the final delete of the legacy layer once W1 and W2 are done (legacy CSS
  layer and style.css, html.zig head/foot, prose.zig, account.zig); commit reviews
- W1 (meiolol-03): legacy lane first (legacy common.md W1: Your games, shell, Daily notes
  33-34; owns html.zig, style.css, account.js). Next: picked when it's done
- W2 (meiolol-3a): legacy lane first (legacy common.md W2: admin A4-A7, tester T4b-T6,
  pv.js, URL5; owns admin*, tester*). Next: picked when done (L6 APP3 went
  to W4). Was: L6 desktop APP3 (docs/plan/app.md: the
  lane panel switches to any ally's role on a seat click, then the blind-safe ranking,
  J2), on the Mac with deploy/mock-cs.sh, cards before and after (app.md Status). Files
  then: src/desktop/, the app's board and lane card code, docs/plan/app.md APP3,
  docs/arch-app.md. L5 (latest patch) parked: gpu-box off for a long while (Jacob)
- W3 (meiolol-a3, pane 1554; not 3a): L4 champion page first screen (site.md CH1, CH7;
  check CH1's done-when on today's page first, then the open gaps in
  docs/champion-matchup.md). Files: src/site/champion.zig, builds.zig, ui/champpage.zig,
  champhead.zig, buildpanel.zig, docs/plan/ui/champion.md, site.md "Champion page";
  shared CSS or html.zig changes go to W1 as a patch path. Done: L3 C01 survives a
  reboot, VM7 docs; its files:
  deploy/systemd/ (new C01 system units; the existing units only for ordering on the data disk), a new
  deploy/c01/ (meiolol-disk script, fstab and mount units, installed by a script),
  deploy/health.sh, health-loop.sh, on-push.sh, box.sh (install bits only),
  docs/hosting.md, data-safety.md, compute.md, docs/plan/vm.md, docs/plan/ops.md
  "Storage and hosts", CLAUDE.md "Hosts" lines
- W4 (meiolol-92): desktop shell parity: comp view (APP6) into src/shell, then APP3 in
  the shell (takes W2's L6). Files: src/shell/, new ui component files, src/board.zig,
  src/comp.zig, app.md APP3/APP6, arch-app.md
- W10 (meiolol-w10, pane 181; brief-w10.md): champion icons fade in on /pool and elsewhere
- W9 (meiolol-9e, pane 159; brief-w9.md): Jacob's open notes 35-42 (home, /patch, /your)
- W8 (meiolol-86, pane 157; brief-w8.md): compute sharing Mac and gpu-box tooling
  (Jacob 18:2x); proposal first, builds on meiolol-96's work
- W7 (meiolol-18, pane 154; brief-w7.md): ci wasm size-change report and a lint
  against number formatting in wasm components (Jacob yes, 29 Oct 18:1x). Agrees
  build.zig/deploy edits with meiolol-96
- W6 (meiolol-32, pane 153; brief-w6.md): L5 latest patch (plan.md Now 7,
  patch-transfer.md PT1 pin then patchdays) on the gpu-box. Files: src/lab/,
  patch-transfer.md, model.md, learned.md
- W5 (meiolol-c6): Learn (plan.md Now 3): audit vs docs/plan/ui/learn.md, then steps.
  Files: src/site/learn*.zig, puzzles.zig, ui/learnpage.zig, learndata.zig, puzzle.zig,
  docs/plan/ui/learn.md, site.md "Learn"

## Log
- 29 Oct 10:4x: 4b coordinator (5a relayed Jacob: one team, one new worker). Lanes picked
  from plan.md Now: item 1's open harm (28 Oct's reboot left /srv/meiolol unmounted,
  deploys failed for hours, nothing retries) for W3; items 3 and 7 queued for 03 and 3a
- 29 Oct 10:5x: W3 = meiolol-a3 (pane 1554, right of 4b's 1552), --effort high. 03 and 3a
  told 4b coordinates; they finish legacy lanes first. Waiting on 6a "done: handed over"
- 29 Oct 11:0x: 6a handed over (legacy notes/coord.md): reviews accepted to 424e198e,
  lane 0 and URL4 done; admin-get.sh signs in as meiolol-check, W2 told
- 29 Oct 11:1x: a4450a6f (W3 disk retry, units wait, health mounts) accepted on a read.
  W3 told go for the blocked-Megatron reboot test (~6-8 min down) after its deploy;
  deploy/mac-watch.sh added to W3's files
- 29 Oct 11:2x: accepted on a read: 6ebbcfc2 (W1 /your is the new page, /games 301s),
  3651f058, 7556a3de (W3 mac-watch, C01 docs). Finding to W3: C01 / at 81% (30 GB is
  the dm-cache image), health's 80% alert fires every run; ~1 GB a day grows on /
- 29 Oct 11:31Z: W3 rebooting C01 for the blocked-Megatron test (~6-8 min down). Jacob:
  old URLs get no redirects; 4b removing the old-URL layer (nginx maps, urls.legacy,
  notes migrate, `meiolol urls`, url-smoke); W1 and W2 told
- 29 Oct 11:3x: 1baa2994 (W2 A4c Traffic island, traffic.bin from traffic.json) accepted on a read
- 29 Oct 11:4x: W2 handed over at 217k (pane 1587); next: box check of 1baa2994, then A5
- 29 Oct 11:4x: W3 L3 done (ee72188f: rebooted with Megatron blocked 5 min, came up by
  itself, units +65 s; 3d27d4c6 / counted without cache.img). W3 takes L4 (W1 still on
  legacy lanes 2-3; gpu-box unreachable from the Mac for L5). b1b1f5ee (W1 Y4b CSS) noted
- 29 Oct 11:5x: 367c04ae old-URL layer removed (4b), pushing. C01 nginx and
  /usr/local/bin/meiolol-traffic installed from it by hand (backups *.bak-20261029*);
  renderer stops its old 301s when the deploy swaps it. Another session's Data Dragon
  art WIP is dirty in nginx conf, serve.zig, hosting.md, arch-site.md: not ours
- 29 Oct 12:0x: Jacob: gpu-box off for a long while. L5 parked; W2's next lane is L6
  (desktop APP3). 367c04ae pushed, deploying
- 29 Oct 12:2x: e565a05d (W1 shell S1: preview strip, footer as ui.site), 7668a9a0 (W2
  A5 Deploys and Logs, ui-adminops island) noted. W1 handed over at 25% (keeps the name
  meiolol-03); lane 2 plan S2-S6 in legacy notes/w1.md. Jacob: privacy page made real
  (4b, prose.zig privacy(), docs/legal/privacy.md); W1 told to keep the wording
- 29 Oct 12:3x: 599e91f5 privacy page (4b), pushing. 4b at 25%: handing over (notes/coord.md)
- 29 Oct 12:4x: W2 box checks passed (A4c, A5); W2 handed over at 25%, successor on A6 Models. 599e91f5 pushed
