# W9: Jacob's open site notes 35-42 (team run 2026-10-29-next)

You are W9 in a team run; coordinator meiolol-4b. Read data/team/2026-10-29-next/common.md
first (rules, messages, commits from a clean worktree when the tree is red), then
CLAUDE.md, src/site/CLAUDE.md (notes workflow: deploy/notes.sh, commit.sh --note N) and
docs/frontend.md. Notes: data/team/2026-10-29-next/notes/w9.md (yours). Messages to
meiolol-4b: "done: <sha> <line>", "blocked: <why>, <path>", "question: <path>".

Goal: Jacob's open notes on the live site (`deploy/notes.sh list`), all left at
1800x1042 dark:
- home /: 35 the chart isn't interactive; 36 the Turn / Biggest drop / Best minute
  cards read as moments on the timeline; 38 loads of blank space at the bottom of the
  last-game card
- /patch: 37 the strip (won more, won less, lanes moved, Riot changed, matchups moved)
  is too many words and not clear
- /your: 39 the four top tiles look odd ("2 wins" read as only 2 wins); 40 "Over time"
  card deeper than the others; 41 "All highlights" link in a weird place; 42 the
  highlights view looks lazy and unfinished, lots of blank space
Notes 33-34 (Daily) are W1's, not yours.

Step 1 (no code): for each note, read the page's docs/plan/ui/<page>.md (home.md,
patch.md, your-games.md), look at the page on deploy/dev.sh at 1800 wide dark and at
390, and write in notes/w9.md what is wrong, the fix, and its files. Notes 42 and 37
are design calls. Draw two options for each, as a quick mock or a screenshot of a
dev-only change, and send "question: notes/w9.md" so Jacob can choose. Do the clear
ones (36, 38, 40, 41) straight away, one commit per note with commit.sh --note N.
Check each fix in Chrome at both widths before committing.

Files: the home, patch and Your games components in src/site/ui/ (homepage, patchpage,
yourpage and what they use) and their plan docs. Shared components or CSS used by other
pages (card, tile, chart, ui/site.zig), html.zig and style.css: ask their owner first
(W1 meiolol-03 owns html.zig and style.css; champion files are W3's). wasm families
have a 40 KB gz budget: no h.fmt with {d} in components.
Hand over at 25-33% context with `cc-handover --new` once a step is committed.
