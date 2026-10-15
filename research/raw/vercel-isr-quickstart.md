---
title: Getting started with ISR
product: vercel
url: /docs/incremental-static-regeneration/quickstart
canonical_url: "https://vercel.com/docs/incremental-static-regeneration/quickstart"
last_updated: 2026-08-11
type: tutorial
prerequisites:
  - /docs/incremental-static-regeneration
related:
  - /docs/build-output-api
  - /docs/incremental-static-regeneration
  - /docs/incremental-static-regeneration/limits-and-pricing
summary: Learn how to set up Incremental Static Regeneration (ISR) with time-based and on-demand revalidation.
install_vercel_plugin: npx plugins add vercel/vercel-plugin
---

# Getting started with ISR

This guide helps you set up Incremental Static Regeneration (ISR) with your Vercel project. With ISR, you can regenerate pages without rebuilding and redeploying your site. When a page with ISR enabled regenerates, Vercel fetches the most recent data and updates the cache. There are two ways to trigger regeneration:


<!-- docsgraph:related -->
## Related pages

> **For AI agents:** Follow these links to understand how this page connects to the rest of the Vercel ecosystem. For the full cross-link map (inbound, outbound, prerequisites, and semantic neighbors), see the .graph.md link below.

- [ISR: A flexible way to cache dynamic content](https://vercel.com/blog/isr-a-flexible-way-to-cache-dynamic-content?from=related&source_path=%2Fdocs%2Fincremental-static-regeneration%2Fquickstart&source_site=vercel-docs&relationship=related)
- [How to reduce ISR revalidation costs](https://vercel.com/kb/guide/how-to-reduce-isr-revalidation-costs?from=related&source_path=%2Fdocs%2Fincremental-static-regeneration%2Fquickstart&source_site=vercel-docs&relationship=related) — Reduce ISR costs by analyzing Incremental Static Regeneration \\(ISR\\) behavior to find pages and tags that revalidate to
- [How do I reduce my build time with Next.js on Vercel?](https://vercel.com/kb/guide/how-do-i-reduce-my-build-time-with-next-js-on-vercel?from=related&source_path=%2Fdocs%2Fincremental-static-regeneration%2Fquickstart&source_site=vercel-docs&relationship=related) — Reduce Next.js build times on Vercel by pre-rendering fewer pages at build time, deferring generation with ISR and image
- [Updating large-scale site navigation with minimal revalidation](https://vercel.com/kb/guide/update-mega-nav-min-reval?from=related&source_path=%2Fdocs%2Fincremental-static-regeneration%2Fquickstart&source_site=vercel-docs&relationship=related) — When working with a large number of pages that share a common multi-level navigation, making a navigation update require
- [How to implement Incremental Static Regeneration (ISR)](https://nextjs.org/docs/app/guides/incremental-static-regeneration?from=related&source_path=%2Fdocs%2Fincremental-static-regeneration%2Fquickstart&source_site=vercel-docs&relationship=related) — Learn how to create or update static pages at runtime with Incremental Static Regeneration.
- [How to implement Incremental Static Regeneration (ISR)](https://nextjs.org/docs/pages/guides/incremental-static-regeneration?from=related&source_path=%2Fdocs%2Fincremental-static-regeneration%2Fquickstart&source_site=vercel-docs&relationship=related) — Learn how to create or update static pages at runtime with Incremental Static Regeneration.
- [How to move from time-based to on-demand revalidation](https://vercel.com/kb/guide/how-to-move-to-on-demand-revalidation?from=related&source_path=%2Fdocs%2Fincremental-static-regeneration%2Fquickstart&source_site=vercel-docs&relationship=related) — Replace fixed revalidation timers with scoped updates triggered by changes to content, product data, or other applicatio
- [Vercel Data Cache: A progressive cache, integrated with Next.js](https://vercel.com/blog/vercel-cache-api-nextjs-cache?from=related&source_path=%2Fdocs%2Fincremental-static-regeneration%2Fquickstart&source_site=vercel-docs&relationship=related)
- [Partial Prerendering \\(PPR\\)](https://vercel.com/docs/partial-prerendering?from=related&source_path=%2Fdocs%2Fincremental-static-regeneration%2Fquickstart&source_site=vercel-docs&relationship=related) — Partial Prerendering serves a cached static shell instantly, then renders and streams the dynamic parts of a page per re
- [Vercel CDN overview](https://vercel.com/docs/cdn?from=related&source_path=%2Fdocs%2Fincremental-static-regeneration%2Fquickstart&source_site=vercel-docs&relationship=related) — Vercel's CDN is a globally distributed platform that handles routing, caching, security, and compression for every deplo
- [Vercel Function Logs](https://vercel.com/docs/functions/logs?from=related&source_path=%2Fdocs%2Fincremental-static-regeneration%2Fquickstart&source_site=vercel-docs&relationship=related) — Use runtime logs to debug and monitor your Vercel Functions.
- [Production checklist for launch](https://vercel.com/docs/production-checklist?from=related&source_path=%2Fdocs%2Fincremental-static-regeneration%2Fquickstart&source_site=vercel-docs&relationship=related) — Ensure your application is ready for launch with this comprehensive production checklist by the Vercel engineering team.

Full cross-link map for this page: [/docs/incremental-static-regeneration/quickstart.graph.md](/docs/incremental-static-regeneration/quickstart.graph.md?from=related&source_path=%2Fdocs%2Fincremental-static-regeneration%2Fquickstart&source_site=vercel-docs&relationship=graph)
<!-- /docsgraph:related -->

- **Time-based revalidation**: Regeneration that recurs automatically at a set interval
- **On-demand revalidation**: Regeneration that you trigger explicitly through an API call

You also control when pages are first cached:

- **Pre-render at build time**: Generate pages during the build so the first visitor gets an instant cache hit. This increases build time but avoids slow first requests.
- **Generate on first request**: Skip the build step and let the first visitor trigger generation at runtime. This keeps builds fast but means the first request for each page is slower (a cache miss).

A common pattern is to pre-render popular pages at build time and let the rest generate on demand.

**Agent prompt**

```text
Help me set up Incremental Static Regeneration (ISR) in this project. First, make sure the Vercel CLI is installed (`npm i -g vercel`). If I'm using Claude Code or Cursor, install the Vercel Plugin (`npx plugins add vercel/vercel-plugin`). For other agents, install Vercel Skills (`npx skills add vercel-labs/agent-skills`). Then: 1. Add time-based revalidation to a page using the revalidate option. 2. Show me how to trigger on-demand revalidation with revalidatePath or revalidateTag. 3. Deploy with `vercel --prod` to test ISR behavior.
```

## Prerequisites

- A project deployed on Vercel
- A supported framework: Next.js, SvelteKit, Nuxt, Astro, Gatsby, or a custom solution using the [Build Output API](/docs/build-output-api)

| Framework                  | ISR support                       | On-demand revalidation             |
| -------------------------- | --------------------------------- | ---------------------------------- |
| **Next.js** (App Router)   | `revalidate` route segment config | `revalidatePath` / `revalidateTag` |
| **Next.js** (Pages Router) | `revalidate` in `getStaticProps`  | `res.revalidate` API route         |
| **SvelteKit**              | `config.isr` export               | `x-prerender-revalidate` header    |
| **Nuxt**                   | `routeRules` with `isr` option    | `x-prerender-revalidate` header    |
| **Astro**                  | Server output with ISR config     | Framework-specific                 |
| **Gatsby**                 | Deferred Static Generation (DSG)  | Framework-specific                 |

## Time-based revalidation

Time-based revalidation purges the cache for an ISR route automatically at a set interval. When the interval elapses and a visitor requests the page, Vercel serves the stale version and regenerates the page in the background.

> For \["nextjs"]:

When using Next.js with the `pages` router, you can enable ISR by adding a `revalidate` property to the object returned from `getStaticProps`:

> For \["nextjs-app"]:

When using Next.js with the App Router, you can enable ISR by using the `revalidate` route segment config for a layout or page.

> For \["sveltekit"]:

To deploy a SvelteKit route with ISR, export a config object with an `isr` property. The following example demonstrates a SvelteKit route that Vercel will deploy with ISR, revalidating the page every 60 seconds:

> For \["nuxt"]:

To enable ISR in a Nuxt route, add a `routeRules` option to your `nuxt.config.ts`, as shown in the example below:

**apps/example/page.tsx**

```ts filename="apps/example/page.tsx" framework=nextjs-app
export const revalidate = 10; // seconds
```

**apps/example/page.jsx**

```js filename="apps/example/page.jsx" framework=nextjs-app
export const revalidate = 10; // seconds
```

**pages/example/index.tsx**

```ts filename="pages/example/index.tsx" framework=nextjs
export async function getStaticProps() {
  /* Fetch data here */

  return {
    props: {
      /* Add something to your props */
    },
    revalidate: 10, // Seconds
  };
}
```

**pages/example/index.jsx**

```js filename="pages/example/index.jsx" framework=nextjs
export async function getStaticProps() {
  /* Fetch data here */

  return {
    props: {
      /* Add something to your props */
    },
    revalidate: 10, // Seconds
  };
}
```

**example-route/+page.server.ts**

```ts filename="example-route/+page.server.ts" framework=sveltekit
export const config = {
  isr: {
    expiration: 10,
  },
};
```

**example-route/+page.server.js**

```js filename="example-route/+page.server.js" framework=sveltekit
export const config = {
  isr: {
    expiration: 10,
  },
};
```

**nuxt.config.ts**

```ts filename="nuxt.config.ts" framework=nuxt
export default defineNuxtConfig({
  routeRules: {
    // This route will be revalidated
    // every 10 seconds in the background
    '/blog-posts': { isr: 10 },
  },
});
```

**nuxt.config.js**

```js filename="nuxt.config.js" framework=nuxt
export default defineNuxtConfig({
  routeRules: {
    // This route will be revalidated
    // every 10 seconds in the background
    '/blog-posts': { isr: 10 },
  },
});
```

### Example

The following example renders a list of blog posts from a demo API, revalidating every 10 seconds:

> For \['sveltekit']:

First, create a `+page.server.ts` file that exports your `config` object with `isr` configured and fetches your data:

**routes/blog-posts/+page.server.ts**

```ts filename="routes/blog-posts/+page.server.ts" framework=sveltekit
export const config = {
  isr: {
    expiration: 10,
  },
};

export interface Post {
  title: string;
  id: number;
}

/** @type {import('./$types').PageServerLoad} */
export async function load({ params }) {
  const res = await fetch('https://api.vercel.app/blog');
  return {
    posts: (await res.json()) as Post[],
  };
}
```

**routes/blog-posts/+page.server.js**

```js filename="routes/blog-posts/+page.server.js" framework=sveltekit
export const config = {
	isr: {
		expiration: 10,
	}
};

/** @type {import('./$types').PageServerLoad} */
export async function load({ params }) {
	const res = await fetch('https://api.vercel.app/blog');
	return {
		posts: await res.json()
	};
}
```

> For \['sveltekit']:

Then, create a `+page.svelte` file that renders the list of blog posts:

**routes/blog-posts/+page.svelte**

```tsx filename="routes/blog-posts/+page.svelte" framework=sveltekit
<script>
  /** @type {import('./$types').PageData} */
  export let data;
</script>


<ul>
	{#each data.posts as post}
  <li>{post.title}</li>
	{/each}
</ul>
```

**routes/blog-posts/+page.svelte**

```jsx filename="routes/blog-posts/+page.svelte" framework=sveltekit
<script>
  export let data;
</script>


<ul>
	{#each data.posts as post}
  <li>{post.title}</li>
	{/each}
</ul>
```

> For \['nuxt']:

After enabling ISR in your `nuxt.config.ts` file [as described above](#time-based-revalidation), create an API route that fetches your data:

**server/api/blog-posts.ts**

```ts filename="server/api/blog-posts.ts" framework=nuxt
interface Post {
  title: string;
  id: number;
}

export default defineEventHandler(async (event) => {
  const res = await fetch('https://api.vercel.app/blog');

  const posts = (await res.json()) as Post[];

  return {
    posts,
  };
});
```

**server/api/blog-posts.js**

```js filename="server/api/blog-posts.js" framework=nuxt
export default defineEventHandler(async (event) => {
  const res = await fetch('https://api.vercel.app/blog');

  const posts = await res.json();

  return {
    posts,
  };
});
```

> For \['nuxt']:

Then, fetch the data and render it in a `.vue` file:

**pages/blog-posts/index.vue**

```tsx filename="pages/blog-posts/index.vue" framework=nuxt
<template>
  <ul>
    <li :key="post.id" v-for="post in data.posts">
      {{ post.title }}
    </li>
  </ul>
</template>

<script setup>
  const { data } = await useFetch("/api/blog-posts");
</script>
```

**pages/blog-posts/index.vue**

```jsx filename="pages/blog-posts/index.vue" framework=nuxt
<template>
  <ul>
    <li :key="post.id" v-for="post in data.posts">
      {{ post.title }}
    </li>
  </ul>
</template>

<script setup>
  const { data } = await useFetch("/api/blog-posts");
</script>
```

**pages/blog-posts/index.tsx**

```ts v0="build" filename="pages/blog-posts/index.tsx" framework=nextjs
export async function getStaticProps() {
  const res = await fetch('https://api.vercel.app/blog');
  const posts = await res.json();

  return {
    props: {
      posts,
    },
    revalidate: 10,
  };
}

interface Post {
  title: string;
  id: number;
}

export default function BlogPosts({ posts }: { posts: Post[] }) {
  return (
    <ul>
      {posts.map((post) => (
        <li key={post.id}>{post.title}</li>
      ))}
    </ul>
  );
}
```

**pages/blog-posts/index.jsx**

```js v0="build" filename="pages/blog-posts/index.jsx" framework=nextjs
export async function getStaticProps() {
  const res = await fetch('https://api.vercel.app/blog');
  const posts = await res.json();

  return {
    props: {
      posts,
    },
    revalidate: 10,
  };
}

export default function BlogPosts({ posts }) {
  return (
    <ul>
      {posts.map((post) => (
        <li key={post.id}>{post.title}</li>
      ))}
    </ul>
  );
}
```

**app/blog-posts/page.tsx**

```ts v0="build" filename="app/blog-posts/page.tsx" framework=nextjs-app
export const revalidate = 10; // seconds

interface Post {
  title: string;
  id: number;
}

export default async function Page() {
  const res = await fetch('https://api.vercel.app/blog');
  const posts = (await res.json()) as Post[];
  return (
    <ul>
      {posts.map((post: Post) => {
        return <li key={post.id}>{post.title}</li>;
      })}
    </ul>
  );
}
```

**app/blog-posts/page.jsx**

```js v0="build" filename="app/blog-posts/page.jsx" framework=nextjs-app
export const revalidate = 10; // seconds

export default async function Page() {
  const res = await fetch('https://api.vercel.app/blog');
  const posts = await res.json();

  return (
    <ul>
      {posts.map((post) => {
        return <li key={post.id}>{post.title}</li>;
      })}
    </ul>
  );
}
```

To test this code, run the appropriate `dev` command for your framework and navigate to the `/blog-posts/` route.

You should see a bulleted list of blog posts.

## On-demand revalidation

On-demand revalidation lets you purge the cache for an ISR route at any time, without waiting for a time interval to elapse. This is useful when your content changes based on external events, such as a CMS publish or a webhook.

Tag-based revalidation is the recommended approach for granular control. Instead of revalidating entire paths, you tag cached content and invalidate specific tags when the underlying data changes.

> For \['sveltekit']:

To trigger revalidation with SvelteKit:

1. Set a `BYPASS_TOKEN` Environment Variable with a secret value
2. Assign your Environment Variable to the `bypassToken` config option for your route:

**routes/example-route/+page.server.ts**

```ts filename="routes/example-route/+page.server.ts" framework=sveltekit
import { BYPASS_TOKEN } from '$env/static/private';

export const config = {
  isr: {
    expiration: 10,
    bypassToken: BYPASS_TOKEN,
  },
};
```

**routes/example-route/+page.server.js**

```js filename="routes/example-route/+page.server.js" framework=sveltekit
import { BYPASS_TOKEN } from '$env/static/private';

export const config = {
  isr: {
    expiration: 10,
    bypassToken: BYPASS_TOKEN,
  },
};
```

3. Send a `GET` or `HEAD` API request to your route with the following header:

```bash
x-prerender-revalidate: bypass_token_here
```

> For \['nuxt']:

To trigger revalidation with Nuxt:

1. Set a `BYPASS_TOKEN` Environment Variable with a secret value
2. Assign your Environment Variable to the `bypassToken` config option in `nitro.config` file:

**nitro.config.ts**

```ts filename="nitro.config.ts" framework=nuxt
export default defineNitroConfig({
  vercel: {
    config: {
      bypassToken: process.env.BYPASS_TOKEN,
    },
  },
});
```

**nitro.config.js**

```js filename="nitro.config.js" framework=nuxt
export default defineNitroConfig({
  vercel: {
    config: {
      bypassToken: process.env.BYPASS_TOKEN,
    },
  },
});
```

3. Assign your Environment Variable to the `bypassToken` config option in `nuxt.config` file:

**nuxt.config.ts**

```ts filename="nuxt.config.ts" framework=nuxt
export default defineNuxtConfig({
  nitro: {
    vercel: {
      config: {
        bypassToken: process.env.BYPASS_TOKEN,
      },
    },
  },
});
```

**nuxt.config.js**

```js filename="nuxt.config.js" framework=nuxt
export default defineNuxtConfig({
  nitro: {
    vercel: {
      config: {
        bypassToken: process.env.BYPASS_TOKEN,
      },
    },
  },
});
```

4. Send a `GET` or `HEAD` API request to your route with the following header:

```bash
x-prerender-revalidate: bypass_token_here
```

> For \["nextjs", "nextjs-app"]:

To revalidate a page on demand with Next.js:

1. Create an Environment Variable which will store a revalidation secret
2. Create an API Route that checks for the secret, then triggers revalidation

The following example demonstrates an API route that triggers revalidation if the query parameter `?secret` matches a secret Environment Variable:

```js v0="build" filename="pages/api/revalidate.js" framework=nextjs
export default async function handler(request, response) {
  // Check for secret to confirm this is a valid request
  if (request.query.secret !== process.env.MY_SECRET_TOKEN) {
    return response.status(401).json({ message: 'Invalid token' });
  }

  try {
    // This should be the actual path, not a rewritten path
    // e.g. for "/blog-posts/[slug]" this should be "/blog-posts/1"
    await response.revalidate('/blog-posts');
    return response.json({ revalidated: true });
  } catch (err) {
    // If there was an error, Next.js will continue
    // to show the last successfully generated page
    return response.status(500).send('Error revalidating');
  }
}
```

```ts v0="build" filename="pages/api/revalidate.ts" framework=nextjs
import type { NextApiRequest, NextApiResponse } from 'next';

export default async function handler(
  req: NextApiRequest,
  res: NextApiResponse,
) {
  // Check for secret to confirm this is a valid request
  if (req.query.secret !== process.env.MY_SECRET_TOKEN) {
    return res.status(401).json({ message: 'Invalid token' });
  }

  try {
    // This should be the actual path, not a rewritten path
    // e.g. for "/blog-posts/[slug]" this should be "/blog-posts/1"
    await res.revalidate('/blog-posts');
    return res.json({ revalidated: true });
  } catch (err) {
    // If there was an error, Next.js will continue
    // to show the last successfully generated page
    return res.status(500).send('Error revalidating');
  }
}
```

```ts v0="build" filename="app/api/revalidate/route.ts" framework=nextjs-app
import { revalidatePath } from 'next/cache';

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url);
  if (searchParams.get('secret') !== process.env.MY_SECRET_TOKEN) {
    return new Response('Invalid credentials', {
      status: 401,
    });
  }

  revalidatePath('/blog-posts');

  return Response.json({
    revalidated: true,
    now: Date.now(),
  });
}
```

```js v0="build" filename="app/api/revalidate/route.js" framework=nextjs-app
import { revalidatePath } from 'next/cache';

export async function GET(request) {
  const { searchParams } = new URL(request.url);
  if (searchParams.get('secret') !== process.env.MY_SECRET_TOKEN) {
    return new Response('Invalid credentials', {
      status: 401,
    });
  }

  revalidatePath('/blog-posts');

  return Response.json({
    revalidated: true,
    now: Date.now(),
  });
}
```

> For \["nextjs"]:

> **💡 Note:** You do not need to specify `revalidate` inside `getStaticProps` to use
> on-demand revalidation. If `revalidate` is omitted, Next.js will use the
> default value of `false` (no revalidation) and only revalidate the page
> on-demand when `response.revalidate` is called.

> For \["nextjs", "nextjs-app", "sveltekit"]:

See the [time-based revalidation section above](#time-based-revalidation) for a full ISR example.

## Observability

You can observe your project's ISR usage in the [**ISR**](https://vercel.com/d?to=%2F%5Bteam%5D%2F%5Bproject%5D%2Fobservability%2Fisr\&title=Go+to+ISR+Observability) section of the [**Observability**](https://vercel.com/d?to=%2F%5Bteam%5D%2F%7E%2Fobservability\&title=Try+Observability) tab in the Vercel dashboard.

The **ISR** section provides graphs to help you understand cache behavior and spend:

- **ISR Usage**: The read and write units you're billed for. Correlate data here with the revalidation graphs to find what drives your spend.
- **Request Caching**: The amount of hits vs misses and the share of requests that Vercel serves from which cache layer.
- **Time-based Revalidations**: How often pages are regenerated based on a timer. Use time-based revalidations when content needs to update but you don't have a webhook. Otherwise, use tag-based invalidation to only regenerate when you know the content has changed.
- **Tag Revalidations**: How often a page is regenerated due to an on-demand tag revalidation. Tag content with unique keys and invalidate only the pages that need to update when the content change.

## Templates

## Next steps

- [How ISR works](/docs/incremental-static-regeneration#how-isr-works): Understand the request flow from build time through revalidation
- [Caching on Vercel](/docs/incremental-static-regeneration#caching-on-vercel): Compare ISR with other caching strategies
- [ISR usage and pricing](/docs/incremental-static-regeneration/limits-and-pricing): Understand costs and optimization strategies
- [Monitor ISR](#observability): Track ISR reads, writes, and revalidations in your dashboard


---

[View full sitemap](/docs/sitemap)
