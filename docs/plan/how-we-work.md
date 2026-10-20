# Plan: how we work

Several Claude sessions in parallel, all on main in the one checkout (Jacob,
2026-10-11: no more branches or worktrees). Commit, push and deploy rules: CLAUDE.md
"Git and deploys".

Until the site goes public (Jacob, 2026-10-11): sessions merge, push and redeploy the
preview site and box binary without asking. Still ask first: anything irreversible
(deleting data, key or registration changes, Riot applications), nginx/systemd changes on
the jomify server, changes to Jacob's Mac. Live DB migrations: backup and rehearsal on a
copy first.

Jacob's standing asks: the coordinator reviews regularly for gaps nobody owns (risks,
safety nets, doc requirements with no work behind them) and hands out work. Close a
session once it passes ~30% context: it commits, reports done/next/questions, and its
next steps land here.

Team size (lesson of the 13-14 Oct night, ~60 sessions, 396 commits): 4-5 agents at
once. Beyond that, coordination ate the gain: name clashes, a whole snapshot's runs
voided by a mid-night re-cut, the gpu-box at load 41-58 on 20 threads (jobs 5-10x
slow), by-path commits sweeping in other sessions' hunks. Fix the split and pin before
starting runs on a snapshot, not during.
Unattended runs (17 Oct night): the Mac slept at 22:33 and killed the fix agent
mid-turn, and a usage limit stopped two agents at 21:44. Start the coordinator under
`caffeinate -i`, keep team notes in data/team/ (CLAUDE.md), and long box jobs in
systemd units, not a foreground ssh.
Push CI (J17, 20 Oct): lab and nn tests left `zig build ci` for `zig build test-lab`
(deploy/lab-run.sh runs it once per lab harness before a build); learn.practice reads
each game once; synth tests on fewer games. Warm ci on a one-line core change, Mac at
load 13-17: 56 s to 38 s; idle, compile 18 s plus run 11 s, ~30 s. Next if wanted: the
backend test compile (18 s, LLVM Debug) is now most of it; splitting pipeline_test into
its own test binary would compile in parallel but costs memory on the 24 GB Mac.
Self-hosted backend (-fno-llvm) on the Mac reached 32 GB on a one-test file: not usable.
Tried and dropped: the lane-model fixture needs 150 games (100 with timelines); lean's
"planted" test needs its 60k games (absolute tolerances)
