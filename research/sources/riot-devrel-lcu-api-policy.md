---
title: "Changes to the LCU API Policy (Riot DevRel, 2019-01-24)"
url: https://www.riotgames.com/en/DevRel/changes-to-the-lcu-api-policy
kind: docs
commit:
for: [league-apps-feature-matrix]
looked: 2026-10-22
depth: docs (whole post)
relevance: medium
grade: A/weak
description: Riot DevRel tightens League Client API use three months after allowing it: Korea banned, notify before release, approved endpoints only
---
# Changes to the LCU API Policy (Riot DevRel, 2019-01-24)

Why: the start of the rules for client (LCU) apps, which champ select tools rely on.

## Assessment

- Evidence: A. Riot DevRel post by Gene Chorba, 24 Jan 2019.
- Reasoning: weak. Rules only; the reason is "reviewing some of the applications".
- Interests: Riot.
- Weigh: old, but the notify-before-release rule survives in today's docs
  ([[riot-docs-lol#^f13]]). The approved endpoint list is no longer published.

## Findings

- [policy] LCU apps allowed from Oct 2018, tightened in Jan 2019 after Riot reviewed
  released apps. ^f1
  > We announced in October 2018 that developers could begin to create tools using the LCU API
  > After reviewing some of the applications that have been released and talking to our regional offices we will be making some changes.
- [tools/removed] [policy] Korea: players may not use LCU apps (2019). ^f2
  > For the time being we will no longer allow players in Korea to use applications leveraging the League Client API.
- [policy] Developers must tell Riot before releasing an LCU app or an update to one. ^f3
  > Before you release an application (or an update to your existing application) that uses the League Client API in any region, you must contact us and let us know.
- [policy] Only endpoints on Riot's approved list may be used. ^f4
  > Only endpoints on our approved list are allowed for use by developers
- [policy] (inferred) Riot governs LCU apps by notice and endpoint allow-listing, not
  by key type, so a private tool reading the LCU (champ select session, auto actions)
  is under the same policy as a public one. ^f5

## Read

- whole post

## Not read

- the Oct 2018 "League Client APIs Policy Update" (a stub linking to docs; skipped)
