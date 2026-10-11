---
title: Cloudflare Workers limits (docs, 2026-10-08)
url: https://developers.cloudflare.com/workers/platform/limits/
kind: docs
commit:
for: [free-hosting-storage]
looked: 2026-10-11
depth: docs (Account plan limits, CPU time)
relevance: high
grade: A/fair
description: Cloudflare Workers Free plan: 100,000 requests a day, 10 ms CPU, 20,000 static asset files of 25 MiB each per Worker
---
# Cloudflare Workers limits (docs, 2026-10-08)

Why: could Workers host the site and a small API for free?

## Assessment

- Evidence: A. Vendor's own page, current on 2026-10-11.
- Reasoning: fair.
- Interests: vendor.
- Weigh: binding limits; free tiers change often, recheck before relying on one.

## Findings

- [ops] Workers Free: 100,000 requests a day, 10 ms CPU per request, 128 MB memory. ^f1
  > | [Requests](https://developers.cloudflare.com/workers/platform/limits/#daily-requests) | 100,000/day | No limit |
  > | [CPU time](https://developers.cloudflare.com/workers/platform/limits/#cpu-time) | 10 ms | 5 min |
- [ops] 20,000 static asset files per Worker version on Free, 25 MiB each. ^f2
  > | Number of [Static Asset](https://developers.cloudflare.com/workers/platform/limits/#static-assets) files per Worker version | 20,000 | 100,000 |
- [ops] (inferred) The Zig API (SQLite) cannot run on Workers as is; it would need a
  rewrite to D1 or stay on a VM. The static site fits if it stays under 20,000 files. ^f3

## Read

- account plan limits, CPU time

## Not read

- KV, D1, Durable Objects limits
