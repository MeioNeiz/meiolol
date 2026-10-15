---
title: 'Vercel: Incremental Static Regeneration (docs, 2026)'
url: https://vercel.com/docs/incremental-static-regeneration.md
kind: docs
commit: 
for: [render-cache-invalidation]
looked: 2026-10-15
depth: docs (whole overview)
relevance: high
grade: A/fair
description: Vercel's ISR overview: popular pages prerendered at build and the rest on demand, a cache scoped to each deployment, background revalidation keeping stale on failure
---
# Vercel: Incremental Static Regeneration (docs, 2026)

Why: the hosting side of ISR: how a platform scopes the page cache to a code version and
what it recommends prerendering. Fetched as the page's Markdown variant (`.md`); the
HTML page came back as a cookie banner.

## Assessment

- Evidence: A. The largest ISR host, describing its own platform.
- Reasoning: fair. Lists behaviour and benefits; little on why or costs.
- Interests: vendor; the page sells the managed CDN.
- Weigh: trust the mechanisms (deployment-scoped cache, stale on failure); the
  "popular pages" advice is a one-liner with no method for choosing them.

## Findings

- [render] Vercel's own advice: prerender popular pages at build time, generate the rest on demand, to keep builds fast. ^f1
  > You can pre-render popular pages at build time and generate the rest on demand as visitors request them. This speeds up your builds.
- [render] [ops] Code deploys invalidate by scoping: each deployment gets its own ISR cache and never reuses the previous one's. ^f2
  > It is scoped to a specific deployment where each deployment generates its own cache.
  > However, each new deployment uses its own ISR cache and does not reuse the cache from a previous deployment.
- [render] [ops] Old deployments' caches are kept, so a rollback serves already-rendered pages. ^f3
  > Cached content from previous deployments are not purged, so you can roll back without losing previously generated content.
- [render] Unused entries age out: the durable cache drops a page after 31 days without access. ^f4
  > persists content for the duration you specify, until you revalidate it or it goes unaccessed for 31 days.
- [render] Concurrent misses on one path collapse into one render, as nginx's proxy_cache_lock does ([[nginx-proxy-module#^f3]]). ^f5
  > When multiple requests hit the same uncached path at once, Vercel collapses them into a single invocation.
- [render] A failed revalidation keeps serving stale and retries in 30 s; failure includes any status other than 200, redirects, 404 or 410. ^f6
  > When a failure occurs, Vercel preserves the stale content and sets a 30-second Time-To-Live (TTL), so it retries revalidation shortly after.
- [render] On-demand revalidation affects only the deployment it was triggered on. ^f7
  > On-demand revalidation applies to the domain and deployment where you trigger it, and doesn't affect subdomains or other deployments.
- [render] (inferred) For meiolol: "cache per deployment" equals putting the binary's version in nginx's proxy_cache_key; old entries become unreachable and age out by `inactive`. ^f8

## Read

- whole overview page

## Not read

- request collapsing page, limits and pricing, ISR cache region
