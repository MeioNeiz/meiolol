---
title: GitHub Docs: GitHub Pages limits
url: https://docs.github.com/en/pages/getting-started-with-github-pages/github-pages-limits
kind: docs
commit:
for: [free-hosting-storage]
looked: 2026-10-11
depth: docs (whole page)
relevance: high
grade: A/fair
description: GitHub Pages limits: 1 GB site, 100 GB/month soft bandwidth, 10 builds/hour soft, not for online business, e-commerce or SaaS
---
# GitHub Docs: GitHub Pages limits

Why: can meiolol use GitHub to store backups or data, and what are the limits?

## Assessment

- Evidence: A. GitHub's own docs, current on 2026-10-11.
- Reasoning: fair.
- Interests: vendor (platform terms).
- Weigh: binding limits and policy wording.

## Findings

- [ops] Published sites at most 1 GB; source repos recommended under 1 GB. ^f1
  > Published GitHub Pages sites may be no larger than 1 GB.
- [ops] Soft bandwidth limit 100 GB a month. ^f2
  > GitHub Pages sites have a _soft_ bandwidth limit of 100 GB per month.
- [ops] Deployments time out after 10 minutes; soft 10 builds per hour unless deployed by
  a custom Actions workflow. ^f3
  > GitHub Pages deployments will timeout if they take longer than 10 minutes.
- [ops] [policy] Not for online business, e-commerce or SaaS sites. ^f4
  > GitHub Pages is not intended for or allowed to be used as a free web-hosting service to run your online business, e-commerce site, or any other website that is primarily directed at either facilitating commercial transactions or providing commercial software as a service (SaaS).

## Read

- whole page

## Not read

- Pages custom domain docs
