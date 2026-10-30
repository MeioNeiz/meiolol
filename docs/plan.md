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

Ranked by harm: outages and data risk, then what Riot's reviewers see, then what brings
players back.

1. Storage and hosts: C01 runs everything (docs/plan/vm.md; data disk 405 GB free on 30
   Oct at ~3.6 GB a day). Left: the gpu-box step once it is on Tailscale, VM7-8;
   gpu-box WSL compaction: ops.md "Storage and hosts"
2. Front end from the ground up (J29, J30): one UI for the site and the desktop. Page
   plans and the foundation in docs/plan/ui/, the stack in docs/plan/ui/stack.md,
   Jacob's answers in each plan. Next: a visual pass on the gallery and the mocks he
   found plain, with the foundation build (tree core, island runtime) beside it.
   Direction: docs/frontend.md
3. Champion and matchup pages to LoLalytics' level (gaps, measurements and target
   layout: docs/champion-matchup.md): site.md CH0 (Jacob's choices), then the open CH
   and MU steps, CH1 first screen first; Learn redesign (docs/learn-proposal.md); Daily
   Draft pick verdicts (site.md "Daily Draft")
4. Application: Jacob checks the draft text and pastes it (production-key.md);
   screenshots, video and LCU list need his real champ select run (app.md APP1);
   docs/privacy-rules.md lists what the text and privacy page must still match (J10);
   eight gaps for Jacob (archive wording and LCU list in the text, controller name, mail
   retention): data/team/2026-10-23-progress/prodkey-notes.md "For Jacob"
5. Accounts and two apps (J21): roles public, paid, private, admin, owner. Jacob's:
   the AC4 desktop sign-in cut-over (release, testers sign in, then the shared key
   goes), the first private accounts, APP1 (real capture). Next: app.md APP3-APP4
   against the mock; the Draft tester moves to the private site (app.md "Private site")
6. Comp leans: the held-out look, then champion pages and reasons: data-and-model.md.
   The desktop app gets A4 once web-loop.sh's strip_fitted goes
7. The latest patch (J25, J27, J28): docs/plan/patch-transfer.md. Evaluate on
   latest-patch games only, day by day; old patches always pooled with a correction
   between patches (shrunk per-patch offsets the main candidate). PT1-PT3 dev done
   (A2, pooled + offsets, wins from day 1); the frozen test look on 16.21 days 4+
   (model.md) waits Jacob's go; the Patch changes page says why each champion moved
   (site.md PC1-PC2)
8. The data edge (J23, J24): day cubes as storage (E7) so any patch, season, rank and
   region is a sum, a public truth test (E2) and "Meio", one estimate per number from
   every game, patch and season history views (E10): docs/plan/estimates.md. Items 6
   and 7 feed it
9. Our Zig "libraries" toward what the Rust crates give, checks outside ci: the open
   additions in docs/plan/libraries.md
10. Jacob's open decisions: decisions.md "Open decisions"
11. Professional URLs (J32): done, every page on the scheme (docs/plan/urls.md)
12. Build speed (Jacob 29 Oct: keep sessions working at pace): next BS2 (slots mean
    cores), BS3 (ci and deploy builds on the gpu-box, with W8), BS4 (slow tests):
    docs/plan/build-speed.md

Others own: the TW2 mastery retry (meiolol-8f); neural nets vs today's model; the
draft's "Rammus into high AD/AP" check.

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
