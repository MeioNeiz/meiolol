# Plan: how we work

Several Claude sessions in parallel, all on main in the one checkout (no branches or
worktrees). Commit, push and deploy rules: CLAUDE.md "Git and deploys".

Until the site goes public: sessions merge, push and redeploy the preview site and box
binary without asking. Still ask first: anything irreversible (deleting data, key or
registration changes, Riot applications), nginx/systemd changes on the jomify server,
changes to Jacob's Mac. Live DB migrations: backup and rehearsal on a copy first.

Jacob's standing asks: the coordinator reviews regularly for gaps nobody owns (risks,
safety nets, doc requirements with no work behind them) and hands out work. Close a
session once it passes ~30% context: it commits, reports done/next/questions, and its
next steps land here.

Team size: 4-5 agents at once. Beyond that coordination eats the gain: name clashes,
runs voided by a mid-run re-cut, the gpu-box overloaded (jobs 5-10x slow), by-path
commits sweeping in other sessions' hunks. Fix the split and pin before starting runs
on a snapshot, not during.

Unattended runs: start the coordinator under `caffeinate -i` (a sleeping Mac kills
agents mid-turn; usage limits stop them too), keep team notes in data/team/
(CLAUDE.md), and long box jobs in systemd units, not a foreground ssh.

Push CI (J17): lab and nn tests run in `zig build test-lab`, not `zig build ci`
(deploy/lab-run.sh runs it once per lab harness before a build). Warm ci on a one-line
core change is ~30-40 s; the backend test compile (~18 s, LLVM Debug) is most of it.
Next if wanted: pipeline_test as its own test binary (compiles in parallel, costs memory
on the 24 GB Mac). Ruled out: the self-hosted backend (-fno-llvm) reached 32 GB on a
one-test file; the lane-model fixture needs 150 games (100 with timelines); lean's
"planted" test needs its 60k games (absolute tolerances).
