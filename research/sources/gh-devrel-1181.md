---
title: "developer-relations #1181: RSO app request form on the beta portal fails after a 2026 VALORANT production approval"
url: https://api.github.com/repos/RiotGames/developer-relations/issues/1181
kind: thread
commit:
for: [prodkey-review-2026]
looked: 2026-11-13
depth: listed (issue body)
relevance: low
grade: C/fair
description: An approved VALORANT production app must request RSO through the beta portal and implement OAuth within 30 days of approval; the form 500s
---
# developer-relations #1181: RSO request after approval

## Assessment

- Evidence: C. Developer report with network traces.
- Reasoning: fair.
- Interests: none.
- Weigh: VALORANT; shows production approvals do happen in 2026 and what follows them.

## Findings

- [policy] After a VALORANT production approval, the portal invites an RSO request on beta.developer.riotgames.com. ^f1
  > After a VALORANT production API key is approved, the Developer Portal sends an invite to request RSO game access via the App Request Form.
- [policy] Developer reports a 30-day window to implement OAuth after approval (VALORANT). ^f2
  > within the 30-day window following key approval
- [policy] (inferred) Production approvals were still being issued in mid-2026, at least for VALORANT. ^f3

## Read

- Issue body
