# W8: share compute between the Mac and the gpu-box (team run 2026-10-29-next)

You are W8 in a team run; coordinator meiolol-4b. Read data/team/2026-10-29-next/common.md
first (rules, messages), then CLAUDE.md "Hosts", "Build and test", "Working style",
docs/compute.md, docs/lab-run.md, docs/dev-flow.md. Notes:
data/team/2026-10-29-next/notes/w8.md (yours). Messages to meiolol-4b: "done: <sha>
<line>", "blocked: <why>, <path>", "question: <path>".

Goal (Jacob, 29 Oct): tooling so the Mac (M5, 10 cores, 24 GB) and the gpu-box
(i5-13600KF, 20 threads, 32 GB, RTX 3080, WSL2, `ssh gpu-box`) share compute better.
Today ~10 Claude sessions share the Mac: at 17:30-18:05 load hit 106 on 10 cores, 15 zig
compiles at once, 8.7 GB swap, a deploy build took 40 min, while the gpu-box sat idle.
Today's pieces: deploy/slots.sh (Mac-only build slots; weight 1 doesn't stop a zig build
using -j10), zb.sh, lab-run.sh and lab-watch.sh (gpu-box lab runs, paused while League
runs), build-tree.sh (clean worktree builds), push.sh pre-push ci.

What we want: a heavy build, test or ci run goes to whichever host has room, without each
session choosing. One view of load and queue across both hosts. The Mac stays responsive
for the sessions and Jacob's browser. Results and errors come back as if run locally.
Constraints to design for:
- the gpu-box is Jacob's gaming PC. League pauses runs, it sleeps, and WSL restarts. A run
  sent there must survive that or fall back to the Mac.
- source sync cost: dirty shared checkout, worktrees, zig caches on each side.
- cross-compiled outputs must match.

Step 1 (no code on main): measure, then write a proposal in notes/w8.md:
- what each build kind costs on each host
- sync time
- the design
- what changes in slots.sh, zb.sh and push.sh
Send "question: notes/w8.md" for Jacob's yes.

meiolol-96 (outside the team) owns build speed: moving ci to the gpu-box, a -j cap per
slot weight, and comptime asset hashing moved out of the build. Jacob froze build.zig,
zb.sh, slots.sh, commit.sh and the hooks on main until he has its numbers and agrees.
Message meiolol-96 first, split the work so you don't do it twice (it may already have
gpu-box ci timings), and build on its proposal rather than beside it.

Files: new tools under deploy/ or tools/, docs/compute.md, docs/dev-flow.md. The frozen
files only after Jacob's yes. Never touch the box (C01) or ~/ml/meiolol on the gpu-box.
Warn the sessions using the gpu-box (cc-peers) before restarting WSL.
Hand over at 25-33% context with `cc-handover --new` once a step is committed.
