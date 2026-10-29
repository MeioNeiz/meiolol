# Restart: team run 2026-10-29-next (saved 29 Oct ~20:30, Mac going off)

Picking this up on another machine: read this, then common.md, then notes/coord.md, then
the notes file of the lane you take. Branch wip/mac-2026-10-29 holds this folder, the
shared checkout's uncommitted work, and wip/mac-2026-10-29-<worktree> one per worktree.

## Live
- origin/main da32b5b2 (W4 comp view + Windows fix on 7dab0fe9). meiolol-96's 0ffb8740
  (asset hash + CSS bundle by build tools, not comptime) was queued to push next
- The Mac's local main 38362842 = a3's rebase of 80bbc328 and 4421179c: discard, use origin

## Waiting to go on main (cherry-pick onto origin/main, re-hash, ci, push)
- W2: URL5 949af2ff (/private, /admin without .html, no redirects; C01 nginx by hand,
  see legacy notes/w2.md) then 113cb5bb (review fixes 1-7: training.bin made-stamp, lab-push
  builds its own meiolol, picks chart, etc). After the push, sync deploy/lab-push.sh into
  the checkout launchd runs
- W5: bd07bc71 step 3 (chapter-end drafts) + step 4 (myth card, ChoiceCards wrap, Learn
  icons via champ.icon_fmt): notes/w5.md
- W10: /pool and champion search icons from ddragon PNGs -> champ.icon_fmt: notes/w10.md
- W9: notes 35, 36, 38, 40, 41 fixes; Jacob picked 37 A (counts in chips), 42 A (card per
  group), 39 graphical streak (big figure + result pips, show Jacob a screenshot first)
- 4b: notes tool Enter saves, Shift+Enter new line (src/site/ui/wasm/notes.zig onKey,
  inText): in the wip snapshot, not browser-checked
- W8: 2f188591 compute sharing steps 1-2 (place.sh, remote-build.sh, compute.sh)

## Open decisions for Jacob
- e3 portraits: one 120 px AVIF q60 per champion (0.79x bytes, sharper everywhere,
  0 wasm bytes). (1) avifenc in the art pipeline + libavif-bin on C01? (2) no fallback for
  non-AVIF browsers (recommended) or nginx Accept switch? Table: e3's scratchpad
  portraits-avif.md (may be lost with the Mac; numbers in coord.md)
- W8 steps 3-4: tests and pre-push ci routed to the gpu-box (zb.sh, pre-push, build.zig
  ci-mac step); after 96's build.zig change
- W7: wire tools/wasmsize.zig and tools/fmtlint.zig into ci (patch in its worktree)
- Admin switch-over (A7): after URL5 and A6c, or earlier with runs/campaigns left on the
  old page
- Pick-up difficulty somewhere general again (pool.md "later"): where?
- gpu-box Windows Tailscale stuck (nobody logged in): C01 unreachable from it, snapshot
  build failed, backup mirror stale since 28 Oct 21:18Z (W6, notes/w6.md)

## Lanes (owner, notes file, next)
- W1 meiolol-03: shell S4 text pages, then S5 account, S6 scope chips, Daily notes 33-34
  (legacy notes/w1.md); owns html.zig, style.css
- W2 meiolol-3a: above, then A6c, A7 switch-over, tester, pv.js (legacy notes/w2.md)
- W3 champion page (handed over): L4 "More charts" left: early kills, by rank (notes/w3.md)
- W4 meiolol-57: APP3 shell-side (ui-app has ~700 B room, patch was 1.5 KB), then the app
  review pages under /p/ (notes/w4.md, w4-app3.patch)
- W5 meiolol-c1: Learn after step 4: myth cards, numbers refresh (notes/w5.md)
- W6 meiolol-32: L5 latest patch, PT1 pin then patchdays on the gpu-box (notes/w6.md)
- W7 meiolol-18: wasm size report + fmt lint (notes/w7.md)
- W8 meiolol-86: Mac/gpu-box compute sharing (notes/w8.md)
- W9 meiolol-9e: Jacob's notes 35-42 (notes/w9.md, w9-mocks/)
- W10 meiolol-w10: icons (notes/w10.md)
- Outside the team: meiolol-96 build speed (data/team/2026-10-29-build-speed/notes.md),
  meiolol-e3 PageSpeed (CSP/Trusted Types work, portraits), meiolol-b2 per-page CSS
- Review findings: notes/review-29oct.md (8: 1-7 W2 done in 113cb5bb, 8 W1)

## On the PC (gpu-box WSL)
- Secrets: ~/.secrets/*.env (mode 600): meiolol-repo.env (the repo's .env, RIOT_API_KEY:
  copy to the clone's .env), meiolol--essex-vm/local/desktop, jodrive--namecheap/oracle
- ssh essex-vm works from WSL (key ~/.ssh/essex_vm, authorised on C01 29 Oct)
- Unpushed work per worktree: branches wip/mac-2026-10-29-wt/<session8>-<dir>; the
  session id prefix matches the transcript names in ~/.claude*/projects (Mac only).
  W2 URL5 = 63af78f7-wt, review fixes = 63af78f7-wt2; W5 = 16cdb943-wp; W7 = d7366677-w7;
  W10 = meiolol-w10; 96 build speed = meiolol-.claude-worktrees-speed2; e3 = 9c56ab72-named
- Config to recreate: MeioNeiz/claude-config (README), MeioNeiz/wezterm (setup-windows.ps1),
  MeioNeiz/kev-mcp setup/
- W10 question: build an 80 px AVIF icon atlas (one request per patch, every icon at once;
  notes/w10.md) with e3? Its /pool fix (80 KB instead of 674 KB) is in its worktree
