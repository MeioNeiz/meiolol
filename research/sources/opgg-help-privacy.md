---
title: 'OP.GG Help Center: "I want to keep my OP.GG private" and "still visible after deactivation" (Wayback, 2025)'
url: https://opgg.helpscoutdocs.com/article/295-summoner
kind: docs
commit:
for: [identity-and-privacy]
looked: 2026-10-11
depth: docs (both articles, archived copies)
relevance: high
grade: A/weak
description: OP.GG's stock answer to removal requests: it shows whatever the Riot API serves and only drops a profile once Riot deletes the account
---
# OP.GG Help Center: privacy and removal articles

Why: how the largest lookup site handles "remove my profile" requests in practice.

## Assessment

- Evidence: A for what OP.GG does (its own help centre); Wayback copies from March 2025,
  articles last updated 12 Jan 2023. Help centre has since moved (old URLs 404).
- Reasoning: weak. Asserts; does not reconcile with the erasure right in its own policy
  ([[opgg-privacy-policy#^f2]]).
- Interests: OP.GG.
- Weigh: shows industry practice: no per-player removal; the Riot account deletion
  pipeline is treated as the only removal path. Whether that satisfies GDPR is untested.
  The two articles are stored together in raw/opgg-help-privacy.md.

## Findings

- [privacy] OP.GG says it cannot delete summoner information unless it is deleted from
  the official Riot API. ^f1
  > All information and data on our services comply with the League of Legends official API, and we cannot delete summoner information unless it is permanently deleted from the League of Legends official API.
- [privacy] After Riot deletes an account, it shows as "del#number" or a random number on
  other players' pages. ^f2
  > your account will only appear as **‘del#number’** or **‘random number’** on other players’ summoner pages.
- [privacy] Flat refusal to edit or delete. ^f3
  > OP.GG does not delete or modify summoner information.
- [privacy] (inferred) The only privacy control a player has against lookup sites is
  Riot's (account deletion, or streamer mode hiding [[riot-dev-streamer-mode-2025#^f1]]);
  sites mirror the API rather than run their own opt-out. ^f4

## Read

- articles 295 and 294 (archived)

## Not read

- current help.op.gg (403 to curl)
