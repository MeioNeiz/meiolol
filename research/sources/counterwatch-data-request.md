---
title: 'Counterwatch: Data requests and your rights (observed-player data, 2026)'
url: https://www.counterwatch.gg/data-request
kind: docs
commit:
for: [identity-and-privacy]
looked: 2026-10-11
depth: docs (whole page)
relevance: high
grade: C/strong
description: Small Swedish Overwatch/Marvel Rivals tracker's data request page: legitimate interest for observed players, objection by anyone, ownership verification before removal
---
# Counterwatch: Data requests and your rights

Why: a small EU stats company's explicit handling of players who never used the app,
the exact case meiolol's crawler creates (other games, same problem).

## Assessment

- Evidence: C. Small Swedish company (Supre.me AB), Overwolf companion app for Overwatch
  and Marvel Rivals; works for its author; no evidence of regulator scrutiny either way.
- Reasoning: strong. Names the basis, who can object, how ownership is checked, the
  limits (backups, bookkeeping) and the regulator.
- Interests: Counterwatch.
- Weigh: the clearest written model found for observed-player data; better than the
  big League sites, which are silent on it ([[opgg-privacy-policy#^f3]],
  [[ugg-privacy#^f6]]).

## Findings

- [privacy] Anyone can make a request; no account needed; players who only appear in
  tracked matches can object or ask for removal. ^f1
  > Anyone can. You do not need a Counterwatch account.
  > Players who never used the app: if your in-game identifier (such as an Overwatch BattleTag or a Marvel Rivals / NetEase id) appears in our data because you were in a tracked match, you can object to that processing or ask us to remove your identifier.
- [privacy] Observed players' identifiers and match stats processed on legitimate interest
  for community stats and live features; objections lead to redaction or removal. ^f2
  > We record in-game identifiers and match stats of players seen in tracked matches to produce community statistics and power the app's live-match features, on the basis of legitimate interest.
  > we will redact or remove it once we have verified a reasonable connection to it.
- [privacy] Ownership check before acting; may decline if the identifier cannot be
  reasonably linked to the requester. ^f3
  > Because deleting an unverified identifier would affect someone else's data, we may ask for more information and may decline a request where we cannot reasonably establish that the identifier is yours.
- [privacy] Response within one month of verification, extendable by two months. ^f4
  > we respond within one month of verifying your request. For complex or numerous requests we may extend this by up to two further months
- [privacy] Backups age out on schedule rather than being edited. ^f5
  > We do not surgically edit individual records out of backups.
- [privacy] (inferred) The same pattern fits meiolol: legitimate interest for crawled
  players, an objection form, and the profile-icon challenge as the "reasonable
  connection" check before removal ([[lolsite-icon-verify#^f4]]). ^f6

## Read

- whole page

## Not read

- counterwatch.gg/privacy#legitimate-interest (their full balancing reasoning)
