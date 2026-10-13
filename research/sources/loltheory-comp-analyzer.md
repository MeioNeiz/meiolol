---
title: LoLTheory Team Comp Analyzer (Oct 2026)
url: https://loltheory.gg/team-comp-analyzer/
kind: project
commit: 
for: [search-demand]
looked: 2026-10-12
depth: docs (rendered page text, empty draft state)
relevance: high
grade: C/weak
description: LoLTheory's web team comp analyzer: enter both teams, get a ranked list of picks for your role with win rate delta and score from team composition (Platinum+, patch 16.20); desktop app imports champ select
---
# LoLTheory Team Comp Analyzer (Oct 2026)

Why: does anyone already serve "my pick against the whole enemy team"?

## Assessment

- Evidence: C. Live product; no traffic or method numbers on the page.
- Reasoning: weak on the page: scores without explanation.
- Interests: vendor (desktop app download is the call to action).
- Weigh: shows the format exists; its quality and reach are unknown.

## Findings

- [tools] [draft] A web tool takes both teams' champions and recommends picks for your role, scored on team composition, filtered by rank and patch. ^f1
  > Scores and win rates are based on team composition
  > # What You Should Pick Middle
- [tools] [ux/features] Output is a ranked list of champions with a win rate delta and a score; nothing on the page explains why a pick fits the comp. ^f2
  > Recommended Champions
- [tools] The app imports allies and enemies automatically from champ select. ^f3
  > Download our app to have ally and enemy champions automatically imported for you.
- [policy] (inferred) A ranked pick list in champ select is close to the "single forced pick" meiolol's policy notes rule out; meiolol would need to frame comp data as explained facts, not a ranking to obey. ^f4

## Read

- Rendered page text

## Not read

- loltheory.gg/faq (method), counters and synergies pages
