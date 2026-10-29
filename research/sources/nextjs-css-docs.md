---
title: 'Next.js docs: CSS (getting started, ordering and merging)'
url: https://raw.githubusercontent.com/vercel/next.js/canary/docs/01-app/01-getting-started/11-css.mdx
kind: docs
commit: 
for: [css-per-page]
looked: 2026-10-29
depth: docs (CSS Modules, Global CSS, Ordering and Merging, Development vs Production)
relevance: medium
grade: A/fair
description: Next.js App Router CSS guide; order follows import order, global sheets are never removed on navigation, and a list of rules developers follow to keep order predictable
---
# Next.js docs: CSS (getting started, ordering and merging)

Why: what Next.js asks developers to do by hand to keep split CSS correct.

## Assessment

- Evidence: A. Official docs.
- Reasoning: fair. Rules given, reasons brief.
- Interests: vendor; pushes Tailwind.
- Weigh: the recommendations list is the maintenance cost of automatic splitting.

## Findings

- [web] Global CSS imported in a layout or page is not removed on navigation, which can
  conflict; global sheets only for truly global CSS. ^f1
  > this currently does not remove stylesheets as you navigate between routes which can lead to conflicts.
- [web] CSS order is the order of imports in code, across components. ^f2
  > The **order of your CSS** depends on the **order you import styles in your code**.
- [web] Developer upkeep to keep order predictable: one CSS entry, globals at the root,
  no import auto-sorting. ^f3
  > Try to contain CSS imports to a single JavaScript or TypeScript entry file
  > Turn off linters or formatters that auto-sort imports like ESLint’s
- [web] Production splits into many code-split files so a route gets the minimal CSS; dev
  order differs, so check the build. ^f4
  > all CSS files are automatically concatenated into **many minified and code-split** `.css` files, ensuring the minimal amount of CSS is loaded for a route.
  > CSS ordering can behave differently in development, always ensure to check the build (`next build`) to verify the final CSS order.

## Read

- CSS Modules, Global CSS, Ordering and Merging, Development vs Production

## Not read

- Tailwind and Sass setup sections
