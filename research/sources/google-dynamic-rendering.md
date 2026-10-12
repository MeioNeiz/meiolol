---
title: 'Google: Dynamic rendering as a workaround (docs, 2026)'
url: https://developers.google.com/search/docs/crawling-indexing/javascript/dynamic-rendering
kind: docs
commit: 
for: [hybrid-rendering-seo]
looked: 2026-10-12
depth: docs (intro, when to use)
relevance: medium
grade: A/fair
description: Google calls bot-only prerendering a workaround and recommends server-side rendering, static rendering or hydration instead
---
# Google: Dynamic rendering as a workaround (docs, 2026)

Why: is serving bots HTML and people a JS page an option?

## Assessment

- Evidence: A. Google's own docs.
- Reasoning: fair. Says why: complexity and resources.
- Interests: none.
- Weigh: rules out a bot-only path; SSR and static are equal in Google's eyes.

## Findings

- [seo] [render] Google recommends server-side rendering, static rendering or hydration; dynamic rendering for bots is a workaround. ^f1
  > Dynamic rendering was a workaround and not a long-term solution for problems with JavaScript-generated content in search engines. Instead, we recommend that you use [server-side rendering](https://web.dev/articles/rendering-on-the-web#server-side), [static rendering](https://web.dev/articles/rendering-on-the-web#static), or [hydration](https://web.dev/articles/rendering-on-the-web#rehydration)
- [seo] (inferred) Google names server-side and static rendering side by side, so a page rendered on request is not worse for search than a static one, given the same HTML and speed. ^f2

## Read

- intro and when to use

## Not read

- setup steps, cloaking section
