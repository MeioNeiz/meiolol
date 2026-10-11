---
title: Cloudflare Pages limits (docs, 2026)
url: https://developers.cloudflare.com/pages/platform/limits/
kind: docs
commit:
for: [free-hosting-storage]
looked: 2026-10-11
depth: docs (Builds, Files, file size)
relevance: high
grade: A/fair
description: Cloudflare Pages Free plan limits: 20,000 files per site, 25 MiB per file, 500 builds a month; larger files to R2
---
# Cloudflare Pages limits (docs, 2026)

Why: can Cloudflare Pages host the static site?

## Assessment

- Evidence: A. Vendor's own page, current on 2026-10-11.
- Reasoning: fair.
- Interests: vendor.
- Weigh: binding limits; free tiers change often, recheck before relying on one.

## Findings

- [ops] Free plan: up to 20,000 files per site (paid plans 100,000). ^f1
  > Cloudflare Pages sites can contain up to 20,000 files on the Free plan.
- [ops] Max 25 MiB per file. ^f2
  > The maximum file size for a single Cloudflare Pages site asset is 25 MiB.
- [ops] 500 builds a month on Free, one at a time, 20-minute timeout. ^f3
  > | Builds per month | 500 | 5,000 | 20,000 |
- [ops] Cloudflare points new static sites at Workers Static Assets. ^f4
  > **[Workers Static Assets](https://developers.cloudflare.com/workers/static-assets/)** — Deploy static sites as individual Workers.

## Read

- Builds, Files, file size, alternatives note

## Not read

- headers, redirects, functions limits
