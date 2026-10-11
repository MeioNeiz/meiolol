---
title: Cloudflare Workers Static Assets: billing and limitations (docs, 2026-04-23)
url: https://developers.cloudflare.com/workers/static-assets/billing-and-limitations/
kind: docs
commit:
for: [free-hosting-storage]
looked: 2026-10-11
depth: docs (whole page)
relevance: high
grade: A/fair
description: Cloudflare docs: requests to Workers static assets are free and unlimited; only Worker script invocations are billed
---
# Cloudflare Workers Static Assets: billing and limitations (docs, 2026-04-23)

Why: what does serving the static site from Workers cost?

## Assessment

- Evidence: A. Vendor's own page, current on 2026-10-11.
- Reasoning: fair.
- Interests: vendor.
- Weigh: binding limits; free tiers change often, recheck before relying on one.

## Findings

- [ops] Requests to static assets are free and unlimited; Worker script requests bill
  as Workers. ^f1
  > Requests to static assets are free and unlimited. Requests to the Worker script (for example, in the case of SSR content) are billed according to Workers pricing.

## Read

- whole page

## Not read

- routing docs
