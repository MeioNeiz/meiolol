---
title: Riot Developer Portal General Policies (updated 2025-05-29)
url: https://developer.riotgames.com/policies/general
kind: docs
commit:
for: [riot-production-key, identity-and-privacy]
looked: 2026-10-22
depth: docs (whole page)
relevance: high
grade: A/fair
description: Riot's cross-game developer policies; canonical rules for registration, monetisation, game integrity
---
# Riot Developer Portal General Policies (updated 2025-05-29)

Why: which policy lines a champ select pick recommender must satisfy for a production key.

## Assessment

- Evidence: A. Canonical policy from Riot itself; page states last updated May 29, 2025.
- Reasoning: fair. Rules stated, rarely explained; "we get to decide" style discretion.
- Interests: Riot (rule-setter).
- Weigh: binding text, but interpretation is by reviewers; check against approvals in practice.

## Findings

- [policy] Page last updated 29 May 2025. ^f1
  > LAST UPDATED: MAY 29, 2025
- [policy] Required legal boilerplate, visible to players (general-policies wording). ^f2
  > [Your product] isn't endorsed by Riot Games and doesn't reflect the views or opinions of Riot Games or anyone officially involved in producing or managing Riot Games properties.
- [policy] All products must be registered and audited; new features or changes re-audited. ^f3
  > All products must be registered in, and audited by Riot Games through the Developer Portal
  > Any new features or changes to a product must be audited through the product’s page in the Developer Portal
- [policy] LCU products must be registered through the app-type flow. ^f4
  > If your product utilizes the League Client API
- [policy] Monetising requires Approved or Acknowledged status plus a free tier. ^f5
  > You may monetize your product as long as your product is registered on the Developer Portal and your product status is either Approved or Acknowledged.
  > You must have a free tier of access for players, which may include advertising
- [policy] Game integrity: diversity of decisions; highlight, don't remove, decisions; give multiple choices. ^f6
  > Products should increase, and not decrease the diversity of game decisions (builds, compositions, characters, decks).
  > Products should not remove game decisions, but may highlight decisions that are important and give multiple choices to help players make good decisions.
- [policy] No unfair advantage; no MMR/ELO calculators; no de-anonymising. ^f7
  > Products cannot create an unfair advantage for players, like a cheating program or giving some players an advantage that others would not otherwise have.
  > Prohibited alternatives include MMR or ELO calculators.
- [policy] One product per production key; key must not ship in a distributed binary. ^f8
  > Do not use a Production API key to run multiple projects (one product per key)
  > Do not include your API key in your code, especially if you plan on distributing a binary
- [policy] Checked, not there: no mention of machine learning, AI, model training, or data retention on this page. ^f9

- [privacy] [policy] No de-anonymising players who cannot reasonably be identified from
  visible information. ^f10
  > Products cannot de-anonymize players who cannot reasonably be identified from visible information.
- [privacy] Checked, not there: no rule on player consent, opt-in, ownership checks,
  retention or deletion requests on this page. ^f11

- [policy] [tools/paid] No ads in Riot properties: in game, loading screens or the Riot
  Client (the May 2025 rule, [[overwolf-riot-creators-response#^f1]]). ^f12
  > You may not place advertisements in Riot properties, which include in-game, loading screens, and the Riot Client.
- [policy] [tools/paid] Paid products need a free tier, transformative content and no
  gouging. ^f13
  > You must have a free tier of access for players, which may include advertising
  > Your content must be transformative if you are charging players for it
- [policy] (inferred) "All products must be registered and audited" ([[riot-policies-general#^f3]])
  has no key-type carve-out, so the game integrity section binds personal-key products
  too. ^f14

## Read

- whole page

## Not read

- https://developer.riotgames.com/terms: Terms of Use (data use, retention)
