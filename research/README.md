# Research

Prior art for meiolol: originally a League of Legends champ select pick recommender, now
choosing a more Riot-friendly, data-hungry product (the production key goal). Existing
tools of every kind, what Riot encourages, player needs, Riot API data, recommendation
methods. Decisions live in the plan, not here (no plan file yet).

Run with the `josearch` skill (`josearch help`). Start at [index](index.md); search with
`josearch find`. Only `sources/`, `questions/` and this README are hand-written;
`index.md` and `areas/` are generated and `ledger.jsonl` is written by the CLI.

## Tags

Every finding starts with one or more tags. Add tags here before using them. A sub-tag
`parent/child` narrows a tag (declare the parent too); it counts as its parent as well.
Area: which areas/ page the tag's findings go to (blank on a sub-tag: its parent's).

| Tag | Area | Covers |
| --- | --- | --- |
| `tools` | product | existing pick and draft tools (sites, overlays, open-source projects) |
| `method` | stats | recommendation and win-prediction methods, models, features |
| `data` | data | Riot API, match data, sampling, patches, rate limits |
| `draft` | product | draft theory: counters, synergy, roles, comps, how much draft matters |
| `ux` | ui | how meiolol and other tools present things to players: see the ux/* sub-tags |
| `policy` | policy | Riot developer policies, API key approval process, legal requirements |
| `market` | product | popularity, traffic, downloads, monetisation, crowding of tool categories |
| `needs` | product | what players say they want, pain points, complaints about existing tools |
| `learning` | product | improvement and coaching tools: VOD/replay review, matchup guides, feedback |
| `fun` | product | games, quizzes, social and friend features, community and creative tools |
| `privacy` | policy | player identity, Riot ID lookup, consent, data retention, GDPR, privacy policies |
| `stats` | stats | statistical estimation: smoothing, shrinkage, pooling, sample sizes, uncertainty |
| `gui` | ui | desktop GUI libraries and native windowing for the app |
| `web` | ui | the website's UI: HTML generation, templating, client-side JS and wasm |
| `queues` | data | game modes, queue ids, which queues the API serves |
| `toolchain` | ops | Zig versions, build system, compiler and std changes affecting the repo |
| `seo` | ops | search engines: indexing, crawl budget, sitemaps, spam policies, page speed |
| `render` | ops | when pages are built: static generation, on-demand rendering, caching, ISR |
| `ops` | ops | hosting, object storage, backups off-site, free tiers, prices, provider terms |
| `lab` | stats | LLM agents that run modelling experiments: loops, tools, search, tracking, guards |
| `ux/charts` | | chart design, axes, chart types |
| `ux/uncertainty` | | showing spread, error bars, sample size, thin data |
| `ux/colour` | | colour, colour-blind, contrast |
| `ux/trust` | | what makes players trust or distrust numbers |
| `ux/layout` | | navigation, page structure, what goes first |
| `ux/features` | | what competitor tools show and how |
| `ux/density` | | dense tables and number layout: colour-scaled cells, bars or sparklines in cells, small multiples |
| `web/template` | | HTML generation, templating languages, components |
| `web/wasm` | | wasm, JS interop, client-side rendering |
| `ops/io` | | disk IO on the box: schedulers, ionice, cgroup io controls, block volume limits |

## Areas

Generated pages in areas/ gather each area's questions, sources and findings by tag.

| Area | Covers |
| --- | --- |
| `product` | what to build: existing tools, players' needs, market, fun and learning features |
| `policy` | Riot developer policy, production key, player privacy and GDPR |
| `data` | what the Riot API serves and how to crawl it |
| `stats` | estimation and recommendation methods |
| `ui` | the website and app UI: design, charts, templating, wasm, desktop GUI |
| `ops` | hosting, storage, rendering and SEO, toolchain |
