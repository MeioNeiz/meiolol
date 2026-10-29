# W7: wasm size report and number-format lint (team run 2026-10-29-next)

You are W7 in a team run; coordinator meiolol-4b. Read data/team/2026-10-29-next/common.md
first (rules, messages, commits from a clean worktree when the tree is red), then
CLAUDE.md "Git and deploys" and "Build and test", docs/dev-flow.md, and the ui.wasm
budget rule (docs/plan/ui/stack.md, build.zig ui_budget ~line 371, the -size steps ~line 418).
Notes: data/team/2026-10-29-next/notes/w7.md (yours). Messages to meiolol-4b: "done: <sha>
<line>", "blocked: <why>, <path>", "question: <path>".

Why (Jacob agreed 29 Oct): every ui.wasm family has a 40 KB gz budget, checked in ci.
Today d803924c (champion portrait srcset, number formatting via h.fmt with {d} inside a
shared component) added ~470 B gz to ~14 families and pushed three (ui-champmore,
ui-games, ui-daily) over at once. It took three sessions over an hour to find the cause.
Keep the 40 KB rule; make it cheap to live with:

1. Size changes in every ci run: per family, gz size now vs the last pushed main, the
   delta, and a warning at >= 90% of budget. On any growth over a threshold (say 200 B)
   or a failure, say what grew: which functions or symbols, and the source files they
   come from. Pick the cheapest reliable way (a baseline file updated on push, or
   building origin/main's sizes; wasm symbol sizes via a name section or a small Zig
   tool). The failure message alone should point at d803924c's kind of cause in seconds.
2. A lint in ci against number formatting in wasm components: std.fmt / h.fmt with
   numeric placeholders ({d}, {}, {x}...) in the ui code that compiles to wasm, unless
   whitelisted. Check what a cheap shared int-to-text helper exists already (or add one)
   and point the lint message at it. Measure what the existing offenders cost; fixing
   them is a follow-up list in notes, not this lane, unless trivial.

Coordinate with meiolol-96 (outside the team, speeding up builds and tests, possibly
moving ci to the gpu-box): it may be editing build.zig and deploy/ ci scripts. Message it
before touching those files and agree who edits what. Files: build.zig (size steps
only), new tools under tools/ or deploy/, the lint, docs/dev-flow.md and docs/plan/ui/stack.md budget
lines. Not yours: src/site/ components (other workers); report offenders to 4b instead.
Test that a deliberate {d} in a component fails the lint and that the report names it.
Hand over at 25-33% context with `cc-handover --new` once a step is committed.
