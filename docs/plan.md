# Plan

The index: the goal, what to do now, and one file per area under docs/plan/. Read Now,
then only the area you work on. Close or add items in the area file; keep Now short
(pointers, not detail). How area files are written: "Writing plan files" below.

## Goal: production key

Product: "scout your own games" (docs/concept.md "Identity draft four"): the player's
own games first, as stats nobody else shows, with the minute-by-minute matchup curves
as the benchmark; Daily Draft, Learn, Pool kept; picks only as several options with
reasons. Crawl is Platinum IV+ only, so "typical" means Platinum+. The application went
in on 2026-10-11 (docs/production-key.md); review takes 3-9 months and Riot looks at
the site at review time, so keep building and keep the site up. Don't edit the
application while it queues. What pages and the app may show: docs/production-key.md
"Product rules".

## Our edge: understanding the data (J24)

What sets meiolol apart from every other stat site is how well we understand the data,
patch by patch, season by season and rank by rank. Other sites show a raw window (last
30 days, latest patch, a rank cut) and leave the reader to guess how much is luck or
stale. We show every view (30 days, newest patch, any past patch, season, rank,
region), each one honest about its scope, and on top of them our own estimate built
from every game with what we know about how patches, seasons and ranks move numbers.
That same understanding feeds the models, so they beat anyone's. It is a lens for every
step, not one item: a block that ignores its filters, a number from a thin window shown
as fact, or a model fitted on one window without asking what the others add is a gap.
Plan: docs/plan/estimates.md (views, estimate, truth test), patch-transfer.md (how a
patch moves numbers), lab-frontier.md (models); findings land in docs/learned.md

## Now

Legacy UI off first (Jacob, 30 Oct), then by harm: outages and data risk, then what
Riot's reviewers see, then what brings players back. Jacob's open decisions:
decisions.md "Open decisions".

1. Legacy UI off (stack.md; app.md "Private site"). Public done: per-page CSS, a CSP and
   Trusted Types live with no console errors (keep the print.css link: traffic.sh counts
   people by it). Private: /private, /admin, /admin/notes and the tester inline their
   CSS (style.css gone); the old JS tester at /private/old. Done when /private/tester has
   its bans, Random/Fill/Undo, lane model, compare and set net, /private/old, admin.js,
   admin-draft.js, admin-setnet.js and admin.css are gone, pv.js an island. Owners W4
   (tester), W1 (pv.js)
2. Crawler at 99%+ of the key, every region, every hour (ops.md J16): done when hourly
   key use holds 97-100% per region through a gpu-box catch-up and a daily job, with a
   learned.md line. Owner W6; the catch-up test needs the gpu-box on
3. URL leftovers (urls.md URL6): /p/desktop/ and /admin/desktop/ gone (30 Oct). Left:
   the app's update failures (404, 401, 5xx, bad signature, offline) retried with
   backoff, logged, and a plain "get the new version" line after a 404 or 401. Owner W4
4. Alerts and hosts: health alerts reach Jacob's phone (open decision), the gpu-box on
   Tailscale with its backup mirror and archive pull current, VM8 (vm.md), WSL
   compaction when idle (ops.md "Storage and hosts"). Owner coordinator; blocked on
   Jacob
5. The site matches the application as submitted (production-key.md): "friends can group
   up to see recaps of the games they played together" has only Your games' Friends
   view. Squads, minimal (J33; backlog.md "Your games and Squads"), so every claim is one
   click from the home page. Unowned, after a lane frees. APP1 gives the app's
   screenshots
6. Daily Draft and Learn (site.md): Daily's pick verdicts (J26: every option's rank, who
   should have won, lanes won), share with facts; Learn's myth-or-measured cards from
   final learned.md lines. Owner W3
7. Champion and matchup pages to LoLalytics' level (docs/champion-matchup.md): CH0's
   open choices, then site.md's CH Later list. Unowned; CH0 waits Jacob
8. The data edge (J23, J24; estimates.md): E7 day cubes, then E2's truth test, then
   Meio. Items 11 and 12 feed it. Owner W2
9. Accounts and the desktop app (J21; app.md, accounts.md): AC4 sign-in cut-over and
    APP1 real capture (Jacob's), then APP4-APP6's left items. Owner W4 after item 2
10. The latest patch (J25, J27, J28; patch-transfer.md): the frozen 16.21 test look,
    then PT4 and PT6 on A2. Blocked on Jacob's go and the gpu-box
11. Comp leans (data-and-model.md): the held-out look, then champion pages and reasons.
    Blocked on the per-seat stats decision and the gpu-box
12. Build speed (build-speed.md): BS3 waits Jacob. Owner W5
13. Our Zig libraries toward the Rust crates (libraries.md "Next"). Unowned

## Areas

- docs/plan/site.md: the website by page (Your games, Daily Draft, Learn, search,
  champion, matchup, draft tester) and polish before the production review
- docs/plan/app.md: the two desktop apps (public and private), the policy line between
  them, Jacob's champ select list by edition, in-game companion, steps APP1-APP9
- docs/plan/accounts.md: logins, roles (public, paid, private, admin, owner),
  sessions, nginx gate, desktop device tokens, payments later, steps AC0-AC7
- docs/plan/data-and-model.md: what ~800k games support (comp leans, kit groups, model
  work), data and ops proposal, neural nets
- docs/plan/lab-frontier.md: gpu-box experiment programme: draft ceiling, the internal
  teacher model, ensembles, explaining it, causal and patch tests
- docs/plan/patch-transfer.md: training on old patches for the newest, evaluated on
  the newest only
- docs/plan/estimates.md: the data edge (J24): every view (30 days, newest patch, past
  patches, seasons, ranks) and one estimate from every game, scope chips, day cubes,
  the public truth test
- docs/plan/libraries.md: our Zig pieces toward Rust-crate quality, with fuzzing and
  ThreadSanitizer outside ci
- docs/plan/ops.md: crawler speed, traffic, storage and hosts, hosting reference
- docs/plan/urls.md: clean URLs, old-to-new map, 301s, steps URL1-URL5
- docs/plan/vm.md: moving off Oracle onto the Essex VM, steps VM0-VM8
- docs/plan/decisions.md: Jacob's decisions (J, Q, G ids), open decisions, ruled out
- docs/plan/how-we-work.md: sessions, team size, unattended runs
- docs/plan/build-speed.md: build and test times on the Mac, gpu-box builds, steps BS1-BS7
- docs/backlog.md: older next steps by area; check before acting, move what you pick
  up into an area file

## Writing plan files

For the next session, which reads only Now and one area file:
- Area file shape (app.md and accounts.md are the model): intro with the goal and
  decision ids; Steps, ranked, each with an id (APP3, AC1), what, "done when", where to
  start (files) and what blocks it; Jacob's choices as a step of their own (AC0);
  Status, under ~10 lines, pointing at architecture.md or hosting.md for how things
  work; Later
- Current state only. A finished step is deleted, leaving a Status line only if a later
  reader needs it; what changed, when and who ruled it go in the commit message, not
  the plan. A date stays only where a reader acts on it (a deadline, a data cut, an
  order awaited); decision ids (J, Q, G) carry the provenance
- How something works goes in architecture.md, hosting.md or the area's reference doc,
  not the plan
- Commit messages start with the step id when there is one (`git log --grep AC1`)
