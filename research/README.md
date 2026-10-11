# Research

Prior art for meiolol: originally a League of Legends champ select pick recommender, now
choosing a more Riot-friendly, data-hungry product (the production key goal). Existing
tools of every kind, what Riot encourages, player needs, Riot API data, recommendation
methods. Decisions live in the plan, not here (no plan file yet).

Run with the `josearch` skill (`josearch help`). Start at [index](index.md); search with
`josearch find`. Only `sources/`, `questions/` and this README are hand-written;
`index.md` is generated and `ledger.jsonl` is written by the CLI.

## Tags

Every finding starts with one or more tags. Add tags here before using them.

| Tag | Covers |
| --- | --- |
| `tools` | existing pick and draft tools (sites, overlays, open-source projects) |
| `method` | recommendation and win-prediction methods, models, features |
| `data` | Riot API, match data, sampling, patches, rate limits |
| `draft` | draft theory: counters, synergy, roles, comps, how much draft matters |
| `ux` | how recommendations are shown during champ select |
| `policy` | Riot developer policies, API key approval process, legal requirements |
| `market` | popularity, traffic, downloads, monetisation, crowding of tool categories |
| `needs` | what players say they want, pain points, complaints about existing tools |
| `learning` | improvement and coaching tools: VOD/replay review, matchup guides, feedback |
| `fun` | games, quizzes, social and friend features, community and creative tools |
| `privacy` | player identity, Riot ID lookup, consent, data retention, GDPR, privacy policies |
| `stats` | statistical estimation: smoothing, shrinkage, pooling, sample sizes, uncertainty |
| `gui` | desktop GUI libraries and native windowing for the app |
| `queues` | game modes, queue ids, which queues the API serves |
| `toolchain` | Zig versions, build system, compiler and std changes affecting the repo |
| `ops` | hosting, object storage, backups off-site, free tiers, prices, provider terms |
