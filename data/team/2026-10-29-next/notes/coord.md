# Coordinator notes (4b)

Read common.md first (rules, Jacob's calls, ownership, log), then the legacy run's
notes/coord.md "How" (clean-worktree commits). This file: state and what's next.

## State (29 Oct 17:3x)
- Workers: W1 meiolol-03 (legacy lane 2 shell: S2 subbar, S3 search island, S4 prose
  pages, S5 account, S6 scope chips; then lane 3 Daily 33-34; plan in legacy
  notes/w1.md), W2 meiolol-3a (legacy: A6, A7, tester T4b-T6, pv.js, URL5 without 301s;
  then next lane by 4b; L6 went to W4), W3 meiolol-a3 (L4 champion page first screen, notes/w3.md),
  W4 meiolol-92 (APP3, then app review pages under /p/ for Jacob's notes), W5 meiolol-c6 (Learn); briefs brief-w4/w5.md
- All worker commits read and accepted up to 918ff452 (W4 shell comp view); W5 also
  owns ui/guess.zig. Open: W4 compView champ .? panic on a champion missing from stats;
  918ff452 refused by ci (ui-app over 40 KB): told split CompView into its own family, no
  budget raise (Jacob 25 Oct answer 3); my 8d365845 (plan.md) rides on its push.
  W4 15:1x: fix on top takes CompView off ui-app (waits for own island) + .? fix; APP3
  parked uncommitted (41.1 KB alone). Told: sibling island like Practice, then APP3, then
  review pages; W4 hands over after the push
  URL5 moved up (Jacob 15:0x): W2 does it right after A6b
- 4b's own commits: 367c04ae old-URL layer removed (deployed; C01 nginx and
  /usr/local/bin/meiolol-traffic installed by hand, backups *.bak-20261029*),
  599e91f5 privacy page made real (Jacob asked), live and checked on C01
- L5 unparked 18:0x (Jacob via a3: gpu-box back, free for builds too): W6 meiolol-32
  (pane 153, brief-w6.md). Jacob to a3: "run ci on the gpu-box next time"; routed to
  meiolol-96 (build speed session)
- Another session's uncommitted Data Dragon art work landed as fb083705; nothing of it
  is ours
- W3 L4 next (29 Oct 13:1x, told): refresh champion-matchup.md "Us" column, then More
  charts one at a time: lane curve vs average opponent, pick-up 5 bands, comeback odds;
  re-measure CH1 after each

- 15:4x: after a restart all workers sat idle (W4 now meiolol-57, W5 meiolol-c1);
  each nudged to carry on from its notes
- 16:1x: main red twice: ui-app (W4 fix 0bc9786b) and ui-champmore 41,335 B gz from
  d803924c (meiolol-e3, PageSpeed, outside the team; told). W3 fixes: Pick-up and Also
  play move to Charts, pushed first
- 16:3x: 4b reverts d803924c's champ.zig (srcset) in a clean worktree on 480cf5fd, then
  ci and pushes the group (A6b, W4 0bc9786b, S3b, W5 480cf5fd, 8d365845). e3 told:
  ChampIcon approach to 4b first; art.zig srcset measured after the revert.
  20:xx: Jacob: 4b STOP coordinating, no messages out. Open at stop: W4 pushing da32b5b2
  (comp view + Windows fix on 7dab0fe9); W5 then rebases step 3+4 (bd07bc71, Learn icons
  fix) onto origin; local main 38362842 (a3's rebase) still to move to origin; W2 URL5
  949af2ff waits for 'main rebased'; W10 /pool icons from ddragon -> champ.icon_fmt;
  e3 tuned 120 px portraits test; 4b's notes Enter-saves change in
  src/site/ui/wasm/notes.zig uncommitted (ui-notes 39.2 KB gz, not browser-checked)
  19:3x: 4b on work (switched, one uncached re-read). Jacob: don't switch running sessions;
  they finish on personal, successors start on work via the folder override. W8 steps
  1-2 go; 3-4 (zb.sh, pre-push, build.zig ci-mac) asked of Jacob, after 96's change
  19:1x: order changed: W4 (80bbc328 + fix 0eadbe95) onto origin 7dab0fe9 and pushes
  first; W5 then onto new origin; then 4b moves local main, then W2 URL5. W9: Jacob
  picked 37 A, 42 A, 39 graphical streak (pips), screenshot before commit. wezterm-d7
  done (uncommitted): handover closes source with bg tasks; work cap falls back to
  personal (account-limits `work * fallback personal`). 96 waits for Jacob's yes in
  its own pane
  18:5x: Jacob: build-speed agent (meiolol-96, data/team/2026-10-29-build-speed/notes.md)
  keep going at pace: told 96 to land comptime-hash move from a worktree on origin, then
  -j cap, gpu-box ci (W8 routing), slow tests. Old meiolol-c1 (pane 94) never closed:
  its own dev server (:8095) kept it 'shell'; closed by 4b; fix routed to wezterm-d7
  18:4x: MAIN SPLIT: origin 7dab0fe9 (W3) vs local 80bbc328 (W4, ci FAILED 18:09) +
  4421179c (W5). Order: W5 (c1-next) cherry-picks onto origin, pushes -> 4b moves local
  main to that sha (shared tree: 7dab0fe9's files already dirty-identical there; reset
  them) -> 'main rebased: <sha>' to W4 (re-applies 80bbc328 + fix) and W2 (URL5
  949af2ff, then review 1-3). 4b's notes Enter change uncommitted, commit after.
  Jacob asked: approve meiolol-96's comptime-hash move (test compile 6 min -> 42 s)?
  18:3x: review done (notes/review-29oct.md, 1 high 2 med 5 low): 1-7 to W2 after URL5,
  8 to W1. W9 meiolol-9e notes 35-42. 4b: notes tool Enter saves, Shift+Enter newline
  (wasm/notes.zig onKey), building. Jacob asked when admin pages switch: A7 after URL5
  (W2 testing 949af2ff) and A6c; new page at /admin/new.html
  18:2x: Jacob: meiolol folder on the work account until 08:00 (cc-account use); all
  live meiolol sessions set to switch at turn end; 4b switches after its review agent.
  W8 meiolol-86 compute sharing. wezterm-d7 fixed cc-handover names (<name>-next until source
  closes), uncommitted in ~/personal/wezterm
  18:1x: Jacob yes to both questions. Review agent (subagent of 4b) on 2bfe25a3 d740ad4d
  0bc9786b ef4d4e13 480cf5fd a62252ed 80bbc328 -> notes/review-29oct.md. W7 meiolol-18 size
  report + lint; build.zig frozen by Jacob for meiolol-96 (build speed, ci to gpu-box,
  comptime hash/minify out: backend test compile 6 min -> 42 s): W7 holds ci wiring as
  a patch, asks 4b, order after 96
  18:08: a51d1e83 DEPLOYED (load back to ~10). a3 pushing 7dab0fe9 on it.
  18:0x: new 4b took over. a51d1e83 deploy (on-push from 17:29) still building: Mac load
  ~106/10 cores, 15 zig compiles, 8.7 GB swap; W4 80bbc328 ci queued behind. Waiting, not
  killing others' builds. Jacob's 2 questions re-asked, no answer yet
  17:29: a51d1e83 PUSHED, main green (carried A6b d740ad4d, W4 0bc9786b, S3b ef4d4e13,
  W5 480cf5fd, 8d365845, a62252ed). All told. ci 'failed opening ui-*.wasm:
  FileNotFound' = shared .zig-cache race: rerun. Not yet checked deployed live.
  Was 17:0x: revert a51d1e83 on main (on a62252ed, another session's nginx headers), pushing
  in background (deploy/push.sh a51d1e83; log in 4b's scratchpad push.log). If ci passes:
  tell W3, e3, W5, W2, W1 main is green. If a budget still fails: A6b TimeChart suspect
  (W1's guess), measure per family
  16:5x: first revert removed icon_big_fmt too (icons.zig uses it): redone keeping the
  consts, only srcset/sizes/bigOf/test out. Worktree
  /var/folders/b9/qd48vtd14m33_hfzbfwb30g40000gn/T/tmp.MAYvK8jS63/wt (detached at
  480cf5fd + revert). After commit.sh: `git update-ref refs/heads/main <new> 480cf5fd`
  in the main checkout (if main moved, cherry-pick), then deploy/push.sh <new>
  (pre-push ci checks every budget). Then tell W3 (meiolol-a3, rebases its Charts move +
  comeback odds), e3 (cheap srcset: 48/56 px only, x-descriptor, no h.fmt), W5, W2
- Jacob 16:xx open questions: (1) a review agent for unread commits 2bfe25a3,
  d740ad4d, 0bc9786b, ef4d4e13, 480cf5fd, a51d1e83's group (all pushed now)? (2) budget rework: size-diff report in ci +
  lint against h.fmt {d} in components now; a session measuring page weights and a
  shared-runtime look; page budgets replace the 40 KB rule only on his say
  Unrouted: ChoiceCards cuts "Almost none" at 390 with 3 cards (choice.zig): give W5

## Next
1. Read worker commits as "done:" messages come; findings back as a message
2. When W1 finishes lane 3, pick its next lane from plan.md Now (candidates: item 3
   Learn redesign or Daily Draft pick verdicts, matchup page Later list; not W3's
   champion files)
3. Final legacy lane, once W1 and W2 are done (legacy notes/coord.md Next 4): delete the
   legacy CSS layer and style.css (move @font-face into the ui head first), html.zig
   head/foot, prose.zig, account.zig; screenshots before and after
4. Hand over at 25-33%

## Gotchas
- zsh: a path list in a variable doesn't split; use an array `P=(a b)` then `$P`
- commit.sh rewrites site-files.txt for its own tree: on a cherry-pick conflict there,
  take main's copy and re-run commit.sh on top of main, then test again
- zb.sh test can print nothing; in a worktree run `deploy/slots.sh 1 zig build test
  --summary line` and read "Build Summary"
