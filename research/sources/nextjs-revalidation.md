---
title: 'Next.js docs: how revalidation works, revalidateTag, deploymentId, generateStaticParams'
url: https://github.com/vercel/next.js/tree/canary/docs
kind: docs
commit: 6dda4371effebcb038671273d342c60fcd7472ed
for: [render-cache-invalidation]
looked: 2026-10-15
depth: docs (how-revalidation-works whole; revalidateTag, deploymentId whole; generateStaticParams subset section)
relevance: high
grade: A/strong
description: Next.js tag-based invalidation (explicit tags plus per-path soft tags, checked by timestamp), revalidateTag semantics, and the deployment ID that keys caches to a code version
---
# Next.js docs: how revalidation works, revalidateTag, deploymentId, generateStaticParams

Why: how does the best-known on-demand renderer decide which cached pages a data change
or a code deploy invalidates? nextjs.org pages came back empty through `browse`, so these
are the same docs from the vercel/next.js repo (`docs/`), snapped at a commit.

## Assessment

- Evidence: A. The framework's own docs; "How revalidation works" is written for
  platform engineers implementing cache handlers, so it describes internals.
- Reasoning: strong. Explains failure modes (multi-instance, CDN skew, cache read and
  write failures) and the trade of availability over consistency.
- Interests: vendor (Vercel), but this is the self-hosting side, not the product pitch.
- Weigh: the tag model is framework-independent and small enough to copy in Zig: a
  map tag -> last invalidation time, each entry keeps its tags and its own time.

## Findings

- [render] Two kinds of revalidation: time-based (stale-while-revalidate after a set age) and on-demand by tag or path. `how-revalidation-works.mdx` ^f1
  > **On-demand revalidation** explicitly invalidates cached content by calling [`revalidateTag()`](/docs/app/api-reference/functions/revalidateTag) or [`revalidatePath()`](/docs/app/api-reference/functions/revalidatePath). The next request to that content triggers a fresh render.
- [render] Developers attach explicit tags to cached data; revalidating a tag invalidates every entry carrying it, across all pages using it. `how-revalidation-works.mdx`, `revalidateTag.mdx` ^f2
  > When [`revalidateTag('my-tag', 'max')`](/docs/app/api-reference/functions/revalidateTag) is called, all cache entries with that tag are invalidated.
  > `revalidateTag` invalidates data with specific tags across all pages that use those tags, while [`revalidatePath`](/docs/app/api-reference/functions/revalidatePath) invalidates specific page or layout paths.
- [render] Path invalidation is the same mechanism: every route gets automatic soft tags for itself and each ancestor layout, and revalidatePath invalidates those. `how-revalidation-works.mdx` ^f3
  > Soft tags enable [`revalidatePath()`](/docs/app/api-reference/functions/revalidatePath) to work through the same tag-based system.
- [render] Invalidation is a timestamp per tag, not a walk over entries: an entry is stale when any of its tags was invalidated after the entry was written. `how-revalidation-works.mdx` ^f4
  > Your handler should treat an entry as stale if the returned timestamp is newer than the entry's own timestamp.
  > Store tag invalidation timestamps in a shared service (Redis, DynamoDB, or a simple HTTP API).
- [render] Invalidation is lazy: revalidateTag only marks data stale; pages re-render as they are visited, served stale meanwhile (recommended), not all at once. `revalidateTag.mdx` ^f5
  > A revalidation is triggered by a request, not by the `revalidateTag` call, so pages using the tag revalidate as they are visited rather than all at once.
  > Calling `revalidateTag` marks the tagged data as stale. The next request for that data kicks off a revalidation and is served stale content while it runs, using stale-while-revalidate semantics.
- [render] `{ expire: 0 }` is the opt-out when stale is wrong: the next request blocks on a fresh render. `revalidateTag.mdx` ^f6
  > Stale content is never served, so the next request is a blocking revalidate/cache miss.
- [render] [ops] Code deploys invalidate by key, not by purge: the deployment ID is part of the cache key, so a new deployment ID misses every old entry. `deploymentId.mdx` ^f7
  > Includes the `deploymentId` in the [`'use cache'` cache key](/docs/app/api-reference/directives/use-cache#cache-keys), invalidating cache entries when the deployment ID changes
- [render] [ops] The same ID busts browser and CDN caches for static assets by query string, and a client seeing a different server ID does a full reload. `deploymentId.mdx` ^f8
  > Appends `?dpl=<deploymentId>` to static asset URLs (JavaScript, CSS, images)
  > When the client detects a mismatch between its deployment ID and the server's (via the response header), it triggers a hard navigation (full page reload) instead of a client-side navigation.
- [render] [ops] A CDN in front must cache related representations of a page together with the same TTL and invalidation, or users see mismatched versions. `how-revalidation-works.mdx` ^f9
  > The primary mitigation is to cache HTML and RSC responses together with the same TTL and invalidation policy
- [render] The system prefers availability: a failed cache write or read degrades to a fresh render, never an error page. `how-revalidation-works.mdx` ^f10
  > Cache failures result in degraded performance (stale content, extra renders), not broken applications.
- [render] Prerender a subset: return a partial list (the example takes the first 10) and the rest render on first visit. `generate-static-params.mdx` ^f11
  > To statically render a subset of paths at build time, and the rest the first time they're visited at runtime, return a partial list of paths:
- [render] Checked, not there: the Next.js docs read here do not say how to pick the subset (no popularity or analytics guidance); Vercel's docs do ([[vercel-isr#^f1]]). ^f12
- [render] (inferred) For meiolol: tags such as `patch:16.20`, `champ:Ahri`, `role:jungle`, plus a code version in the key, map the data model directly; a tag table of last-change times is enough with one renderer, no tag index in nginx needed if the renderer checks freshness itself. ^f13

## Read

- `docs/01-app/02-guides/how-revalidation-works.mdx`: whole
- `docs/01-app/03-api-reference/04-functions/revalidateTag.mdx`: whole
- `docs/01-app/03-api-reference/05-config/01-next-config-js/deploymentId.mdx`: whole
- `docs/01-app/03-api-reference/04-functions/generate-static-params.mdx`: subset section

## Not read

- `docs/01-app/02-guides/cdn-caching.mdx`: how Next.js expects a CDN to cache; Vary
- `docs/01-app/02-guides/self-hosting.mdx`: build ID, shared cache handler (skimmed via grep)
- cacheHandlers reference: exact getExpiration / refreshTags semantics
