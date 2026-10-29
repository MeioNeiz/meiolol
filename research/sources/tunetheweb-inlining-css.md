---
title: 'Tune The Web: Inlining CSS is not for me'
url: https://www.tunetheweb.com/blog/inlining-css-is-not-for-me/
kind: article
commit: 
for: [css-per-page]
looked: 2026-10-29
depth: docs (all)
relevance: high
grade: B/strong
description: Barry Pollard (2015, edited 2021-22) measures inlining his whole sheet on WebPageTest (start render 1.27 s to 0.88 s) and lists ten reasons he still doesn't inline; HTTP/2 push as an alternative, since abandoned
---
# Tune The Web: Inlining CSS is not for me

Why: a measured gain from inlining set against its costs, by someone who chose not to.

## Assessment

- Evidence: B. Expert's own WebPageTest runs on his small site; single-site, 2015 network stack.
- Reasoning: strong: shows the gain, then the costs, says it's partly preference.
- Interests: none beyond his book.
- Weigh: the numbers show the order of the gain on a small site; the cost list is the useful part.

## Findings

- [seo] [web] Pasting the whole sheet into the page cut start render by over a third, 1.271 s to 0.879 s; even cached loads improved, 0.428 s to 0.254 s. The performance benefit ^f1
  > has dropped over a third from 1.271 seconds to 0.879 seconds
- [seo] [web] The mechanism is latency, not bytes: inlining saves a round trip, and fonts the CSS references can start sooner. ^f2
  > By inlining your CSS you can save at least one of those round trip. Additionally there is a domino affect here too as any resources (e.g. fonts) that you need to download can start downloading immediately.
- [seo] [web] Cost: it mostly helps the first page load; once the sheet is cached, browsing the site isn't really faster. Why I don't like ^f3
  > It only really improves the first page load.
- [web] Cost: every page gets bigger, repeating the same CSS. ^f4
  > It makes each page that little bit bigger and unnecessarily repeats the same information on each page.
- [web] Cost: inlining only per-page styles avoids the fold problem but means working out which CSS each page needs, which can change as the reader interacts. ^f5
  > that has a similar (if not more risky) issue of needing to calcuate the CSS needed by the page - which can change as the reader interacts with the page
- [web] Cost: inline CSS weakens CSP, mostly solved since by hashes. ^f6
  > This is pretty much solved with the use of hashes
- [seo] [web] HTTP/2 push of the sheet barely helped (1.203 s to 1.193 s) while inlining gave 0.991 s; push has since been dropped by Chrome. Will HTTP/2 push solve all this? ^f7
  > inlining still beats this hands down with a first paint time of 0.991 seconds
- [web] (inferred) For meio.lol, interaction-only states (islands, toggles, client-rendered panels) are the "changes as the reader interacts" risk: any per-page or inlined subset must include them. ^f8

## Read

- Whole article
