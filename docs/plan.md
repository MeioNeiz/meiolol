# Plan

Updated 2026-10-19. This file is the index: the goal, what to do now, and one file per
area under docs/plan/. Read Now, then only the area you work on. Close or add items in
the area file; keep Now short (pointers, not detail).

## Goal: production key

Product: "scout your own games" (docs/concept.md "Identity draft four", Jacob
2026-10-12): the player's own games first, as stats nobody else shows, with the
minute-by-minute matchup curves as the benchmark; Daily Draft, Learn, Pool kept; picks
only as several options with reasons. Crawl is Platinum IV+ only, so "typical" means
Platinum+. Application started by Jacob 2026-10-11 (docs/production-key.md); review
takes 3-9 months and Riot looks at the site at review time, so keep building and keep
the site up. Don't edit the application while it queues. What pages and the app may
show: docs/production-key.md "Product rules".

## Now

Ranked by harm: outages and data risk, then what Riot's reviewers see, then what brings
players back. 18 Oct's list with its done items: docs/archive/plan-now-2026-10-18.md.

1. Storage: Hetzner BX11 and the rolling window (Jacob orders, needed within ~a week
   of 18 Oct), raw.db VACUUM, gpu-box WSL compaction: ops.md "Storage and hosts"
2. Crawler slower (Jacob 19 Oct): check recovery after 1037318, then dig: ops.md
3. Traffic looks inflated by bots (Jacob 19 Oct): ops.md "Traffic"
4. Application: Jacob checks the 18 Oct draft text and pastes (production-key.md);
   screenshots, video and LCU list need his real champ select run (app.md "Next").
   Before going live, so the text is true: the 24-month sweep over backup segments and
   deleting archive files (privacy.md notes; `archive-age` only blanks hashed PUUIDs)
5. Jacob's 19 Oct product list, by page in site.md and app.md. Suggested order:
   quick fixes (gold chart's "14 min" label), Your games review (the application's
   core), champion and matchup pages (lolalytics-dense), Daily Draft and Learn (fewer
   words), search across the site, draft tester; desktop items after the real champ
   select run, with the policy check in app.md
6. Comp leans: held-out look ~24 Oct, then champion pages and reasons:
   data-and-model.md

Others own: traffic.sh install and the TW2 mastery retry (meiolol-8f); neural nets vs
today's model; the draft's "Rammus into high AD/AP" check.

## Areas

- docs/plan/site.md: the website by page (Your games, Daily Draft, Learn, search,
  champion, matchup, draft tester) and polish before the production review
- docs/plan/app.md: desktop app, Jacob's champ select list with a policy check per item,
  what is built and tested, the real champ select run
- docs/plan/data-and-model.md: what ~800k games support (comp leans, kit groups, model
  work), data and ops proposal, neural nets
- docs/plan/ops.md: crawler speed, traffic, storage and hosts, hosting reference
- docs/plan/decisions.md: Jacob's decisions (J, Q, G ids), open decisions, ruled out
- docs/plan/how-we-work.md: sessions, team size, unattended runs
- docs/backlog.md: older next steps by area (11-17 Oct); check before acting, move what
  you pick up into an area file
