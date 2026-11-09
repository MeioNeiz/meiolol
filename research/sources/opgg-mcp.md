---
title: OP.GG MCP Server (opgginc/opgg-mcp), Nov 2026
url: https://github.com/opgginc/opgg-mcp
kind: project
commit: fb059ec26650de35acd5f6b40bd0429ba9e94883
for: [league-tools-2025-2026]
looked: 2026-11-06
depth: docs (README)
relevance: medium
grade: B/fair
description: OP.GG's official MCP server (repo created 8 Apr 2025, v1.1.0 Dec 2025, pushed Nov 2026): a hosted endpoint that lets any AI agent query OP.GG's LoL, TFT and Valorant stats, profiles and match histories
---
# OP.GG MCP Server (opgginc/opgg-mcp), Nov 2026

Why: how the big stats sites responded to LLM assistants in 2025-2026; does any sell or
give its data to general AI agents?

## Assessment

- Evidence: B. OP.GG's own organisation on GitHub; 105 stars, 4 contributors, MIT,
  created 2025-04-08, latest release v1.1.0 on 2025-12-17, last push 2026-11-05. The repo
  is a README and client glue: the data sits behind OP.GG's hosted endpoint.
- Reasoning: fair. Clear tool list; no terms, rate limits or pricing in the README.
- Interests: vendor.
- Weigh: trust the tool list as what the endpoint offers; usage numbers unknown.

## Findings

- [tools] [market] Since Apr 2025 OP.GG runs an official MCP server: any AI agent can pull
  OP.GG data for League, TFT and Valorant from a hosted endpoint. `README.md` ^f1
  > provides AI agents with access to OP.GG game data for League of Legends, Teamfight Tactics, and Valorant
- [tools] The hosted endpoint is public in the README, with no key or sign-up step shown.
  `README.md` ^f2
  > https://mcp-api.op.gg/mcp
- [tools] Champion tools give win, pick and ban rates, builds, counters and synergies, the
  same content as its champion pages. `README.md` ^f3
  > Get detailed champion stats (win/pick/ban rates), optimal builds (items, runes, skills, spells), counter matchups, and team synergies
- [privacy] Player tools return any summoner's rank, champion pool and recent match
  history, and full game details for all ten players. `README.md` ^f4
  > Get detailed information for a specific game (all players)
  > Get recent match history with per-game stats
- [policy] (inferred) Serving Riot-derived player data to arbitrary third-party AI agents
  sits close to League's "no data broker" rule ([[riot-docs-lol#^f3]]); no Riot comment
  found either way. ^f5
- [method] (inferred) A general chatbot asked about a draft can now quote OP.GG's numbers
  directly, which makes "ask an LLM" a free rival to plain stats lookups. ^f6

## Read

- `README.md`

## Not read

- `src/`, `docs/`, AGENTS.md: rate limits, auth, any terms of use.
- OP.GG's separate esports MCP server (opgginc/esports-mcp).
