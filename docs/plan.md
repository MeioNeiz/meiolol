# Plan

Updated 2026-10-22. This file is the index: the goal, what to do now, and one file per
area under docs/plan/. Read Now, then only the area you work on. Close or add items in
the area file; keep Now short (pointers, not detail). How area files are written:
"Writing plan files" below.

## Goal: production key

Product: "scout your own games" (docs/concept.md "Identity draft four", Jacob
2026-10-12): the player's own games first, as stats nobody else shows, with the
minute-by-minute matchup curves as the benchmark; Daily Draft, Learn, Pool kept; picks
only as several options with reasons. Crawl is Platinum IV+ only, so "typical" means
Platinum+. Application started by Jacob 2026-10-11 (docs/production-key.md); review
takes 3-9 months and Riot looks at the site at review time, so keep building and keep
the site up. Don't edit the application while it queues. What pages and the app may
show: docs/production-key.md "Product rules".

## Our edge: understanding the data (J24)

Jacob 22 Oct: what sets meiolol apart from every other stat site is how well we
understand the data, patch by patch, season by season and rank by rank. Other sites show
a raw window (last 30 days, latest patch, a rank cut) and leave the reader to guess how
much is luck or stale. We show every view (30 days, newest patch, any past patch, season,
rank, region), each one honest about its scope, and on top of them our own estimate built
from every game with what we know about how patches, seasons and ranks move numbers.
That same understanding feeds the models, so they beat anyone's. It is a lens for every
step, not one item: a block that ignores its filters, a number from a thin window shown
as fact, or a model fitted on one window without asking what the others add is a gap.
Plan: docs/plan/estimates.md (views, estimate, truth test), patch-transfer.md (how a
patch moves numbers), lab-frontier.md (models); findings land in docs/learned.md

## Now

Ranked by harm: outages and data risk, then what Riot's reviewers see, then what brings
players back. 18 Oct's list with its done items: docs/archive/plan-now-2026-10-18.md.

1. Storage: Hetzner BX11 and the rolling window (Jacob orders; less urgent since raw.db
   VACUUM 21 Oct freed 30 GB, box 42% used), gpu-box WSL compaction: ops.md "Storage
   and hosts"
2. Night run 19-20 Oct (data/team/2026-10-19-night/, questions in decisions.md "Open
   decisions"): crawler recovered; traffic counts people by stylesheet fetch (97% of
   old "people" were bots) and our own visits as bots; jomify logrotate; header search;
   Your games moments, firsts, best minute, filled chart, remembered player and views;
   champion opponents grid, vs usual, builds strip, rune tree; matchup first screen;
   matchups index table; Daily Draft facts, reveal, last pick, J10 recent games; Learn
   one per screen; site-wide colour scale and denser frame; mock champ select on the
   Mac (deploy/mock-cs.sh); privacy rules audit (docs/privacy-rules.md)
3. Front end (Jacob 20 Oct: styling, JS and templates "really holding us back" for
   app development, wants time on it soon): scoped in docs/frontend-rework.md,
   recommends Option A (ui.zig components, CSS tokens and layers, one JS core, hashed
   assets, wasm for the filters redraw, Playwright QA at 390/1280 px; ~8-10 days
   foundation, pages move with design steps 4-9). 22 Oct update in the same doc: all
   feature code in Zig (zero JS is impossible; zjb bridge patched for 0.17, a tpl island
   spike ran with a 5-line loader; server fragments for big data), guardrails from
   design-ideas.md made checkable
   (words, tap targets, colour), qa.sh and a gallery first. Jacob 23 Oct: the pain is
   both the site and the desktop window, so one UI for both; the WebView2 spike against
   dvui moves into the order (doc's "23 Oct"). Waits on Jacob: go or not
4. Next on the site, by size of win: champion and matchup pages to the leaders' level
   (Jacob 22 Oct: "match" LoLalytics; gaps, measurements and target layout in
   docs/champion-matchup.md): site.md CH0 (Jacob's choices), CH1-CH9, MU1-MU8, first
   CH1 first screen, CH2-CH3 build panel with items 4-6 and the skill grid, CH4
   opponents by every role and duos (data exists); Learn redesign
   (docs/learn-proposal.md), Daily Draft pick verdicts (daily notes)
5. Application: Jacob checks the 18 Oct draft text and pastes (production-key.md);
   screenshots, video and LCU list need his real champ select run (app.md APP1);
   docs/privacy-rules.md lists what the text and privacy page must still match (J10)
6. Accounts and two apps (J21, 22 Oct): roles public, paid, private, admin, owner;
   owner and private logins first, then a public app and a private, fuller one.
   accounts.md AC1-AC3 can start now (Jacob: AC0 and the nginx OK); app.md APP2-APP4
   against the mock, APP1 (real capture) is Jacob's. Draft tester moves to the private
   site (app.md "Private site")
7. Comp leans: held-out look ~24 Oct, then champion pages and reasons:
   data-and-model.md
8. The latest patch (J25, 23 Oct): docs/plan/patch-transfer.md. Evaluate on
   latest-patch games only, day by day; old patches only while it is thin (pooled plus
   shrunk per-patch offsets); find the day old patches stop helping. PT1 pin next
9. The data edge (J23, J24): every block respects its filters or is marked (E1, done
   23 Oct: scope chips); next day cubes as storage (E7) so any patch, season, rank and
   region is a sum, a public truth test (E2) and "Meio", one estimate per number from
   every game, patch and season history views (E10): docs/plan/estimates.md. Items 7
   and 8 feed it
10. Our Zig "libraries" toward what the Rust crates give (Jacob 21 Oct), checks outside
   ci: desktop releases signed, fuzzed and ReleaseSafe done; next HTTP server limits,
   backend fuzzing, TSan, one `net` module: docs/plan/libraries.md

Others own: the TW2 mastery retry (meiolol-8f); neural nets vs
today's model; the draft's "Rammus into high AD/AP" check.

## Areas

- docs/plan/site.md: the website by page (Your games, Daily Draft, Learn, search,
  champion, matchup, draft tester) and polish before the production review
- docs/plan/app.md: the two desktop apps (public and private), the policy line between
  them, Jacob's champ select list by edition, in-game companion, steps APP1-APP9
- docs/plan/accounts.md: logins, roles (public, paid, private, admin, owner),
  sessions, nginx gate, desktop device tokens, payments later, steps AC0-AC7
- docs/plan/data-and-model.md: what ~800k games support (comp leans, kit groups, model
  work), data and ops proposal, neural nets
- docs/plan/lab-frontier.md: gpu-box experiment programme (21 Oct): draft ceiling, the
  internal teacher model, ensembles, explaining it, causal and patch tests
- docs/plan/patch-transfer.md: training on old patches for the newest, evaluated on
  the newest only (21 Oct)
- docs/plan/estimates.md: the data edge (J24): every view (30 days, newest patch, past
  patches, seasons, ranks) and one estimate from every game, scope chips, day cubes,
  the public truth test (22 Oct)
- docs/plan/libraries.md: our Zig pieces toward Rust-crate quality, with fuzzing and
  ThreadSanitizer outside ci (21 Oct)
- docs/plan/ops.md: crawler speed, traffic, storage and hosts, hosting reference
- docs/plan/decisions.md: Jacob's decisions (J, Q, G ids), open decisions, ruled out
- docs/plan/how-we-work.md: sessions, team size, unattended runs
- docs/backlog.md: older next steps by area (11-17 Oct); check before acting, move what
  you pick up into an area file

## Writing plan files

For the next session, which reads only Now and one area file:
- Area file shape (app.md and accounts.md are the model): intro with the goal and
  decision ids; Steps, ranked, each with an id (APP3, AC1), what, "done when", where to
  start (files) and what blocks it; Jacob's choices as a step of their own (AC0);
  Status, under ~10 lines, pointing at architecture.md or hosting.md for how things
  work; Later
- How something works goes in architecture.md, hosting.md or the area's reference doc,
  not the plan. History goes to git log: a finished step is deleted, leaving a Status
  line only if a later reader needs it
- Commit messages start with the step id when there is one (`git log --grep AC1`)
- To convert: site.md, ops.md, data-and-model.md, lab-frontier.md,
  libraries.md; install history (old shas, nginx .bak names) in hosting.md and
  your-games.md "Deploy" to docs/archive/install-log.md
