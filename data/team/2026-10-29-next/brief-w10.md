# W10: champion icons fade in on /pool (team run 2026-10-29-next)

You are W10 in a team run; coordinator meiolol-4b. Read data/team/2026-10-29-next/common.md
first (rules, messages, commits from a clean worktree when the tree is red; local main is
mid-shuffle 29 Oct evening: commit from a worktree on origin/main, push your own sha),
then CLAUDE.md, src/site/CLAUDE.md and docs/frontend.md. Notes: notes/w10.md (yours).
Messages to meiolol-4b: "done: <sha> <line>", "blocked: <why>, <path>", "question: <path>".

Jacob (29 Oct 19:4x): "when i go to a page like champ pool and click around the champ
icons slowly fade in, this is stupid i dont want that". Champion icons must show at once,
on first load and on every click, on every page, not just /pool.

Find the cause first, in Chrome on deploy/dev.sh (localhost:8080/pool?champs=ahri, then
click champions, lanes, slots; 1800 wide and 390), with DevTools: network (are icons
re-requested? the cache is immutable on meio.lol, but check), the elements panel (are
img nodes replaced on each render, so they re-decode?), and computed styles (any opacity
transition or animation). Suspects, unconfirmed: `loading="lazy"` on ui/champ.zig:53 and
ui/art.zig:53 (lazy img inside a re-rendered island waits for layout and loads late);
the island replacing img nodes instead of keeping them (missing keys); a [data-busy]
opacity transition like champpage.zig:1294; images without width/height popping in.
Fix it in the shared component so every page gains: likely eager loading for icons above
the fold or in islands, decoding="sync" or keeping the nodes keyed. Mind the 40 KB gz
budget per wasm family (no h.fmt with {d}); measure the families the change touches.
Before/after screen recordings or a frame sequence (playwright) as proof, then commit
and push. Files: ui/champ.zig, ui/art.zig, ui/poolgrid.zig, poolpage.zig, and the
island runtime if the cause is node replacement (ui/wasm/dom.zig: tell 4b first, shared).
Hand over at 25-33% context with `cc-handover --new` once committed.
