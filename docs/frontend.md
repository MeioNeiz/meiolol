# Front end: direction

Hub for any UI work on the site or the desktop app: the lasting direction. Plans,
decisions and status live in the files below.

## Goal (J29)
- One UI for the site and the desktop app, built from the ground up for the long term:
  a component system and the stack under it, not page by page fixes. Quality over speed
- Nothing stays because it exists: tpl, the CSS, chart.wasm, zjb islands and dvui (picked
  9-10 Oct only because it built for Windows from the Mac) are all open. Each layer is
  decided on evidence (spikes, measured) for where the product is going
- All feature code in Zig, no JS beyond a loader, unless the stack decision
  shows that costs too much
- Plans before building; Jacob reviews them

## Good UI here (Jacob's review)
Direction, not rules: we are still planning, and an exact rule applied everywhere turns
into its own design trap. Use judgement per case.
- Far fewer words: the UI should mostly explain itself. Long "how to read this" text is
  the thing to remove
- No colour key where the number describes itself (a win rate's colour is read from the
  win rate); a key can earn its place where colour encodes something the reader can't
  see otherwise
- Tooltips sparingly: for a term or an uncertainty that needs a line, not as a place to
  park words an unclear UI couldn't carry
- Purpose-built components for the data, not generic tables and lists; a real
  (sortable) table where it is a table
- The answer on the first screen; no wasted space
- Interaction: select something to see why, range select, click through, pickers at top
- One component per need, reused across pages and the app
- Learn from other LoL sites (lolalytics for champion pages, runes, builds), then make
  our own

## Working agreements (while planning)
- Components come from the register (docs/plan/ui/components.md; until run
  2026-10-24-ui ends, data/team/2026-10-24-ui/components.md): extend it rather than build
  a page-local copy
- New features wait for or are built in the new way; the old UI gets fixes and data
- Product rules bind every screen: docs/production-key.md "Product rules"
- Measured guardrails (word budgets, label lengths, tap targets) in docs/plan/ui/README.md
  are drafts to test on the first rebuilt page, not settled rules

## Where things are
- Jacob's review: docs/review/page-review-2026-10-24.md
- Foundation (components, guardrails, build order): docs/plan/ui/README.md
- Stack (representation, client runtime, styles, words, desktop toolkit):
  docs/plan/ui/stack.md
- Page plans: docs/plan/ui/<page>.md
- Other sites: research/questions/lol-site-ui.md
- The code before the rebuild, surveyed: docs/frontend-rework.md; every script and where
  its work goes in Zig: docs/js-inventory.md
- Components: src/site/ui/<name>.zig (view, css and gallery states in one file), listed
  in ui.all. Gallery: /gallery on `meiolol dev` (deploy/dev.sh), every state at 320, 390
  and wide. Sweep: deploy/qa.sh (overflow, text under 11 px, tap targets, console
  errors, failed requests; warnings only; --webkit, --shots DIR). Its own build is
  -Dwasm-dev: ui.wasm with safety checks, and zjb handles neither kept nor released
  reported (rule: src/site/ui/wasm/dom.zig's top)
- Status: docs/plan.md "Now" items 1-2 (legacy off)
