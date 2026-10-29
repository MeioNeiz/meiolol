---
title: 'Remix v1 docs: Styling guide (route links, shared and surfaced styles, CSS bundle)'
url: https://raw.githubusercontent.com/remix-run/remix/remix%401.19.3/docs/guides/styling.md
kind: docs
commit: 
for: [css-per-page]
looked: 2026-10-29
depth: docs (intro, CSS Ecosystem and Performance, Regular Stylesheets, Shared Component Styles, CSS bundling intro)
relevance: high
grade: A/strong
description: Remix's manual per-route CSS: each route declares links, added and removed with the route; shared component CSS either one shared.css at root or surfaced up through links exports; why linked URLs beat injected styles
---
# Remix v1 docs: Styling guide (route links, shared and surfaced styles, CSS bundle)

Why: the declared, manual end of the spectrum, with its maintainers' reasons.

## Assessment

- Evidence: A. Official docs of Remix 1.19 (now React Router 7, which keeps `links`).
- Reasoning: strong. Lists the cache benefits of URLs, the plain-CSS problems it solves,
  and answers the boilerplate objection.
- Interests: none (Shopify-backed, no vendor product here).
- Weigh: v1 docs; v2 and React Router 7 moved towards bundler-handled side-effect imports.

## Findings

- [web] Routes declare stylesheets in a `links` export; added while the route is active,
  removed when it is not. ^f1
  > When the route is active, the stylesheet is added to the page. When the route is no longer active, the stylesheet is removed.
- [web] Nested routes' links merge, parents first. ^f2
  > Each nested route's `links` are merged (parents first)
- [web] [render] Why linked URLs: cacheable, shared across pages, parallel with JS, prefetchable,
  and style and component changes don't bust each other's cache. ^f3
  > The URL is cacheable in browsers and CDNs
  > The URL can be shared across pages in the app
  > Changes to components don't break the cache for the styles
- [web] Problems of plain CSS it targets: everything loaded on every page, leaking selectors,
  dead rules. ^f4
  > how and when to load CSS, so it was usually all loaded on every page
  > if some rules weren't even used anymore as the CSS source code grew over time
- [web] Removing sheets on leaving a route limits conflicts to parent routes' styles. ^f5
  > The only chances for conflicts are with the parent routes' styles (and even then, you will likely see the conflict since the parent route is also rendering).
- [web] Shared components, option 1: one `shared.css` at root, scoped by unique class or
  data attribute, one URL for all routes. ^f6
  > Put them all in a `shared.css` file included in `app/root.tsx`.
  > While this file may become large, it'll be at a single URL that will be shared by all routes in the app.
- [web] Option 2: each component exports `links` and routes surface them; admitted cost is
  boilerplate in every route. ^f7
  > An initial reaction to this is that routes have to know more than you want them to.
  > it's not introducing a new dependency, just some boilerplate to get the assets.
- [web] Bundled CSS (CSS Modules etc.) becomes one file for the app, linked by hand so the
  developer controls its order. ^f8
  > the Remix compiler will generate a single CSS file containing all bundled styles in your application.
  > This lets you decide where the CSS file is loaded relative to other stylesheets in your app.

## Read

- sections in depth

## Not read

- Tailwind, PostCSS, Vanilla Extract, CSS-in-JS details; React Router 7 styling docs
