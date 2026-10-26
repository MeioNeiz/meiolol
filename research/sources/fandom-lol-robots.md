---
title: lol.fandom.com robots.txt
url: https://lol.fandom.com/robots.txt
kind: docs
commit: 
for: [leaguepedia-daily-fetch]
looked: 2026-10-26
depth: docs (whole file)
relevance: high
grade: A/fair
description: Leaguepedia robots.txt: api.php allowed for all agents, /wiki/Special: (incl. CargoExport) disallowed, AI crawlers blocked
---
# lol.fandom.com robots.txt

Why: which endpoints may a bot use?

## Assessment

- Evidence: A. The site's own file.
- Reasoning: weak (no prose).
- Interests: none.
- Weigh: decisive for which endpoint: api.php yes, Special:CargoExport no.

## Findings

- [policy] api.php is allowed for every user agent. ^f1
  > Allow: /api.php?action=
- [policy] /wiki/Special: is disallowed, so Special:CargoExport (which answered anonymously in our test) is off limits to bots. ^f2
  > Disallow: /wiki/Special:
- [policy] AI crawlers (GPTBot, ClaudeBot, CCBot...) are disallowed site-wide; a non-AI app user agent is not in that list. ^f3
  > User-agent: ClaudeBot
- [policy] A plain curl with our user agent got 403 on robots.txt; Chrome got it. (inferred) Cloudflare bot rules sit in front. ^f4

## Read

- `raw/fandom-lol-robots.md`: whole file.

## Not read

- Nothing.
