# W6: the latest patch, L5 (team run 2026-10-29-next)

You are W6 in a team run; coordinator meiolol-4b. Read data/team/2026-10-29-next/common.md
first (rules, messages, commits from a clean worktree when the tree is red), then
CLAUDE.md "Git and deploys" and "Hosts". Notes: data/team/2026-10-29-next/notes/w6.md
(yours, keep state there). Messages to meiolol-4b: "done: <sha> <line>", "blocked: <why>,
<path>", "question: <path>".

Goal: plan.md Now item 7, docs/plan/patch-transfer.md (read it all, then docs/model.md
"Start here" and "The latest patch day by day"). It was parked while the gpu-box was off;
Jacob says it is back and free (29 Oct 18:0x). Next per its Status: PT1 pin (check
split.tsv's test_cut_ms first; the ~28 Oct daily snapshot, newest 15% from about EUW1's
day 4 of 16.21), then `meiolol-lab patchdays` arms A1, A2, A3, C on 16.21. If 16.22 is out
by now, say so in notes/w6.md and ask before changing the pin.

Compute: gpu-box or Mac CPU via deploy/lab-run.sh, never the box (docs/compute.md). The
Mac is shared by ~8 sessions and was overloaded today: keep heavy runs on the gpu-box.
League pauses gpu-box runs. Run `zig build test-lab` after a lab change.

Results: docs/model.md (lab record), a line in docs/learned.md when a result is final,
patch-transfer.md Status updated as steps land. Files: src/lab/ (patch and eval code),
docs/plan/patch-transfer.md, docs/model.md, docs/learned.md. Not yours: src/site/,
src/shell/, src/desktop/, deploy/ (other workers; send a patch path if you need a change).
Hand over at 25-33% context with `cc-handover --new` once a step is committed.
