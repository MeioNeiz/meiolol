---
title: "Fandom: Terms of Use"
url: https://www.fandom.com/terms-of-use
kind: docs
commit: 
for: [leaguepedia-daily-fetch]
looked: 2026-10-26
depth: skimmed (prohibited uses)
relevance: medium
grade: A/fair
description: Fandom Terms of Use: generic ban on robots and scraping without written permission, carve-out for licensed wiki text, no undue load
---
# Fandom: Terms of Use

Why: does Fandom allow automated API use?

## Assessment

- Evidence: A. Fandom's legal terms.
- Reasoning: weak (boilerplate).
- Interests: Fandom protects ad traffic.
- Weigh: the clauses conflict with Leaguepedia's own published API and bot passwords; read as aimed at scraping pages, but not explicitly carved out.

## Findings

- [policy] Generic ban on robots and automated access without express written permission. ^f1
  > not use any robot, spider, scraper or other automated means to access the Services for any purpose without our express written permission
- [policy] Scraping and reuse of content is barred except where Fandom permits it, e.g. wiki text under the licensing page. ^f2
  > Except as expressly permitted by the Company (for example with respect to the use of text content that is submitted to particular Fandom communities as permitted as set forth at [our licensing page](https://www.fandom.com/licensing))
- [policy] No disproportionate load; do not bypass robot exclusion. ^f3
  > take any action that imposes, or may impose in our sole discretion an unreasonable or disproportionately large load on our infrastructure
  > bypass any measures we may use to prevent or restrict access to the Services, including robot exclusion headers
- [policy] No disguising origin (so a truthful user agent). ^f4
  > Not to forge headers, or manipulate source identifiers or otherwise attempt to disguise the origin
- [policy] (inferred) The API page, bot passwords with a Cargo grant and robots.txt allowing api.php are the express permission in practice; a polite, logged-in, once-a-day api.php query is the defensible reading. Asking in their Discord settles it. ^f5

## Read

- `raw/fandom-terms.md`: prohibited-uses sections.

## Not read

- Rest of the terms (accounts, disputes).
