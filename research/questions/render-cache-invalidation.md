---
status: decided
priority: soon
area: ops
tags: [render, ops]
description: How do sites prerender pages by popularity and invalidate cached pages when code or data changes?
decision: docs/plan.md#site-build-and-deploy-2026-10-12-owner-the-site-session
---
# How do sites prerender pages by popularity and invalidate cached pages when code or data changes?

Feeds: Jacob's long-term direction (15 Oct): prerender pages by how popular they are,
invalidate cached pages when a new version or new data affects them. Today: jomify's
open-source nginx caches meiolol-render's pages (key $uri, 10 min, stale on error and
while updating); docs/hosting.md "Rendering on request", docs/backlog.md "Site build and
deploy".

## Answer

On-demand renderers invalidate by dependency tag, not by URL: each page lists what it
depends on and one purge per tag drops every page carrying it (C1). Next.js does this
lazily, a timestamp per tag compared with each entry's write time on read, so nothing
is purged in bulk (C2). Code deploys don't purge at all: the deployment id is in the
cache key, so old entries are never read again (C3). Open-source nginx can't purge
without a third-party module (C4), but its key can carry a version and unused entries
expire on their own (C3). Prerendering the popular pages and rendering the rest on first
request is the standard split, with no published rule for ranking pages (C5).

For meiolol now (C6): nothing to build while there are no users; the 10 min TTL with
stale-while-updating already refreshes pages after a deploy or new data. When there are
users: a version in nginx's proxy_cache_key (the views file's write time plus the
binary's), and a warm-up after each reload, most visited first, possibly refreshing in
place with proxy_cache_bypass (C7, untested). Tags only if per-patch or per-champion
freshness ever matters.

## Claims

- C1: Mature on-demand renderers and CDNs invalidate by dependency tag (surrogate key), not URL; a page carries many tags and a tag spans many pages. for: [[nextjs-revalidation#^f2]], [[fastly-surrogate-keys#^f1]], [[fastly-surrogate-keys#^f2]], [[cloudflare-cache-tags#^f1]], [[vercel-isr-quickstart#^f3]]
- C2: Tag invalidation can be lazy: a timestamp per tag, compared with the entry's write time when it is read, pages re-rendered one by one on request and served stale meanwhile. for: [[nextjs-revalidation#^f4]], [[nextjs-revalidation#^f5]]
- C3: Code deploys invalidate through a version in the cache key, not a purge; old entries are simply never read and expire. for: [[nextjs-revalidation#^f7]], [[vercel-isr#^f2]], [[nginx-proxy-module#^f6]], [[nginx-proxy-module#^f7]]
- C4: Open-source nginx has no purge (proxy_cache_purge is nginx Plus); the ngx_cache_purge module purges by key or prefix only. for: [[nginx-proxy-module#^f5]], [[ngx-cache-purge#^f1]], [[ngx-cache-purge#^f5]], [[ngx-cache-purge#^f7]]
- C5: Prerender popular pages at build and render the rest on first request; prerendering lengthens the build, and no source says how to choose the pages. for: [[vercel-isr#^f1]], [[vercel-isr-quickstart#^f2]], [[nextjs-revalidation#^f11]], [[nextjs-revalidation#^f12]]
- C6 (inferred): For meiolol, a version in proxy_cache_key and the 10 min TTL suffice; tags (patch, champion, template) would live in the renderer later, with nginx a short-TTL front. from: C2, C3, C4
- C7 (inferred, untested): A warmer can refresh entries in place with a header proxy_cache_bypass acts on, and proxy_cache_revalidate with ETags makes unchanged pages a 304. for: [[nginx-proxy-module#^f8]], [[nginx-proxy-module#^f10]]

## Disagreements

None between sources. C7 rests on our reading: the docs don't say a bypassed response
is stored; test on jomify before relying on it.

## Open

- Which pages to prerender: from meiolol's own traffic (traffic.json), once there is any.
- Leads: Fastly soft purge, Next.js CDN caching doc, a Vercel build-time guide.
