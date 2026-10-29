# W5: Learn (team run 2026-10-29-next)

You are W5 in a team run; coordinator meiolol-4b. Read data/team/2026-10-29-next/common.md
first (rules, messages, commits from a clean worktree when the tree is red), then
CLAUDE.md "Git and deploys" and docs/frontend.md. Notes:
data/team/2026-10-29-next/notes/w5.md (yours, keep state there). Messages to meiolol-4b:
"done: <sha> <line>", "blocked: <why>, <path>", "question: <path>".

Goal: plan.md Now item 3's Learn redesign. Learn is already on the new UI (src/site/
learn.zig, learnbuild.zig, learnfixed.zig, puzzles.zig; ui/learnpage.zig, learndata.zig,
puzzle.zig; commits 26-27 Oct). The plan is docs/plan/ui/learn.md (Jacob's answers at its
end override the sections above them) with docs/learn-proposal.md behind it; site.md
"Learn" Next may be partly stale.

Step 1 (no code): compare docs/plan/ui/learn.md with the live page on deploy/dev.sh
(localhost:8080/learn, 1920x1080 and 390x844) and write in notes/w5.md what is built,
what is open, and an ordered step list (chapter path and strip, chapter 0 from Basics,
chapter-end drafts, stars 0-3, levels by clarity, myth or measured chapter...). Fix
site.md "Learn" to say what is true now. Send "question: notes/w5.md" if a step needs a
Jacob call (e.g. keep or drop Basics); otherwise start on step 1 of your list and send
"done:" per step.

Rules: no win chance or points anywhere in Learn; every number with its games; findings
only from docs/learned.md lines that are final. Files: the Learn files above,
docs/plan/ui/learn.md, site.md "Learn". Shared CSS, html.zig or ui/site.zig: W1
(meiolol-03), send a patch path. Not yours: Daily files (W1), champion files (W3),
desktop and shell (W4), admin*/tester* (W2).
Hand over at 25-33% context with `cc-handover --new` once a step is committed.
