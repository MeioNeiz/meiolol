---
title: Render free instances (docs, 2026)
url: https://render.com/docs/free
kind: docs
commit:
for: [free-hosting-storage]
looked: 2026-10-11
depth: docs (spin-down, filesystem, hours)
relevance: low
grade: A/fair
description: Render Free web services: spin down after 15 idle minutes, about a minute to wake, ephemeral filesystem (local SQLite lost), 750 hours a month
---
# Render free instances (docs, 2026)

Why: can Render's free tier host the Zig API with SQLite?

## Assessment

- Evidence: A. Vendor's own page, current on 2026-10-11.
- Reasoning: fair.
- Interests: vendor.
- Weigh: binding limits; free tiers change often, recheck before relying on one.

## Findings

- [ops] Free web services spin down after 15 minutes idle; waking takes about a minute. ^f1
  > Render **spins down** a Free web service that goes 15 minutes without receiving any inbound traffic.
- [ops] Ephemeral filesystem: local SQLite databases are lost on redeploy, restart or
  spin-down; Free services cannot attach a persistent disk. ^f2
  > Free web services have an [ephemeral filesystem](https://render.com/docs/deploys#ephemeral-filesystem). This means that any changes to your web service's filesystem (uploaded images, local SQLite databases, etc.) are _lost_
  > _Paid_ services can preserve local filesystem changes by attaching a [persistent disk](https://render.com/docs/disks), but Free web services _cannot_.
- [ops] 750 free instance hours per workspace a month. ^f3
  > Render grants **750 Free instance hours** to each workspace per calendar month:

## Read

- spin-down, filesystem, instance hours

## Not read

- free Postgres and Key Value limits
