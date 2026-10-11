---
title: Counterwatch Privacy Policy (section 5, observed players; section 11, retention)
url: https://www.counterwatch.gg/privacy
kind: docs
commit:
for: [identity-and-privacy]
looked: 2026-10-11
depth: docs (sections 4, 5, 11, 12)
relevance: high
grade: C/strong
origin: counterwatch-data-request
description: Swedish game tracker's written legitimate-interest balancing for non-user players, pseudonymised match archive, retention per data type
---
# Counterwatch Privacy Policy

Why: a written legitimate-interest balancing test for processing players who never
signed up; a template for meiolol's LIA and privacy notice.

## Assessment

- Evidence: C. Same small company as [[counterwatch-data-request]] (hence `origin`).
- Reasoning: strong. Gives the balancing reasons, data minimisation, pseudonymisation
  and concrete retention periods.
- Interests: Counterwatch.
- Weigh: well-reasoned but unreviewed by a regulator; Overwatch data comes from an
  Overwolf integration, not a publisher API, so the "visible in game" argument is
  slightly different from Riot API data.

## Findings

- [privacy] Most observed players are not users; processed under Art 6(1)(f). ^f1
  > Most of those players are not Counterwatch users. We process this data under the legitimate interest basis in Article 6(1)(f) GDPR.
- [privacy] Balancing in brief: data already visible in game, only what the game exposes,
  no ad profiles, no contact, no sale, community benefit, redaction on objection. ^f2
  > Our balancing test, in short: the data is already visible inside the game to everyone in the match; we use only what the game exposes; we do not build advertising profiles from it, contact observed players, or sell it; and aggregate statistics benefit the whole player community.
- [privacy] Collected: identifiers, heroes, per-match stats; no contact details, real
  identity or special-category data. ^f3
  > We do not collect contact details, real-world identity, or any special-category data about observed players.
- [privacy] [data] Match archive pseudonymised within days (at most a month): identifiers
  replaced by random codes, with a separate code-to-identifier table. ^f4
  > usually within two days, and at most one month, we replace every identifier, every name and your account id with a random code and delete the original upload.
- [privacy] [data] Retention: archive 24 months; code link deleted about 25 months after
  the player's last appearance, sooner on objection. ^f5
  > Match archive: 24 months from the upload, then deleted automatically.
  > Your entry in the table that links codes to identifiers is deleted about 25 months after the last upload you appear in, and sooner when your account is deleted or when you object or ask for erasure.
- [privacy] (inferred) Maps onto meiolol: keep the crawled match store keyed by PUUID
  for the curves, but the curves are aggregates; a separate PUUID-to-Riot ID link can be
  dropped on objection or rtbf without losing statistics. ^f6
- [privacy] Pseudonymised copy is still personal data while the code link exists. ^f7
  > A coded copy is still personal data while that link exists.
- [privacy] Observed players can include children; same limits and objection rights. ^f8
  > Overwatch and Marvel Rivals are played by minors, so the players we observe can include children.
- [privacy] Website shows aggregates only, no individual players; the app shows players
  only for the user's own matches. ^f9
  > the website currently shows community statistics in aggregate only. It does not list individual players.
  > The desktop app shows individual players for your own matches, the same information the game itself shows you on the scoreboard.

## Read

- sections 4 (bases), 5 (observed players), 11 (retention), 12 (rights) by grep

## Not read

- cookies, payments, standalone app sections
