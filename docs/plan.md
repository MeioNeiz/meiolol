# Plan

Updated 2026-10-20. This file is the index: the goal, what to do now, and one file per
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
   foundation, pages move with design steps 4-9). Waits on Jacob: A or not, and whether
   "app" means the site or the desktop window (dvui, shares nothing with the site)
4. Next on the site, by size of win: Learn redesign (docs/learn-proposal.md), design
   build order 4-6 (docs/design-ideas.md), per-matchup builds (vsbuilds notes), Daily
   Draft pick verdicts (daily notes); Jacob's answers to the night's questions first
5. Application: Jacob checks the 18 Oct draft text and pastes (production-key.md);
   screenshots, video and LCU list need his real champ select run (app.md "Next");
   docs/privacy-rules.md lists what the text and privacy page must still match (J10)
6. Draft tester and desktop items from Jacob's 19 Oct list (site.md, app.md), desktop
   after the real champ select run, with the policy check in app.md
7. Comp leans: held-out look ~24 Oct, then champion pages and reasons:
   data-and-model.md

Others own: the TW2 mastery retry (meiolol-8f); neural nets vs
today's model; the draft's "Rammus into high AD/AP" check.

## Areas

- docs/plan/site.md: the website by page (Your games, Daily Draft, Learn, search,
  champion, matchup, draft tester) and polish before the production review
- docs/plan/app.md: desktop app, Jacob's champ select list with a policy check per item,
  what is built and tested, the real champ select run
- docs/plan/data-and-model.md: what ~800k games support (comp leans, kit groups, model
  work), data and ops proposal, neural nets
- docs/plan/lab-frontier.md: gpu-box experiment programme (21 Oct): draft ceiling, the
  internal teacher model, ensembles, explaining it, causal and patch tests
- docs/plan/ops.md: crawler speed, traffic, storage and hosts, hosting reference
- docs/plan/decisions.md: Jacob's decisions (J, Q, G ids), open decisions, ruled out
- docs/plan/how-we-work.md: sessions, team size, unattended runs
- docs/backlog.md: older next steps by area (11-17 Oct); check before acting, move what
  you pick up into an area file
