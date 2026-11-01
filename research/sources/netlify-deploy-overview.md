---
title: 'Netlify docs: Deploy overview'
url: https://docs.netlify.com/site-deploys/overview
kind: docs
commit:
for: [deploy-progress-ui]
looked: 2026-11-01
depth: docs (deploy summary, deploy log)
relevance: high
grade: A/fair
description: Netlify deploy detail page: deploy summary of outcomes (files uploaded, headers, redirects, functions) above the full deploy log
---
# Netlify docs: Deploy overview

Why: Netlify's deploy summary and log.

## Assessment

- Evidence: A. Official docs of a major host.
- Reasoning: fair.
- Interests: vendor docs.
- Weigh: trust.

## Findings

- [ux/progress] Successful deploys get a summary above the log, linking into it. ^f1
  > You can find a deploy summary on the detail page of any successful deploy, right above the [deploy log](https://docs.netlify.com/deploy/deploy-overview#deploy-log). It allows you to quickly identify your deploy status and refer to the details in the log based on different types of information.
- [ux/progress] The summary counts outcomes: files uploaded, headers and redirects status, functions deployed. ^f2
  > This summary indicates how many files have been uploaded to our CDN. It also indicates the status of site [headers](https://docs.netlify.com/manage/routing/headers) and [redirects](https://docs.netlify.com/manage/routing/redirects/overview) included in the deploy. It also shows you how many [functions](https://docs.netlify.com/build/functions/overview) and [edge functions](https://docs.netlify.com/build/edge-functions/overview) were deployed.
- [ux/progress] The summary compares with earlier deploys: files already uploaded by a previous deploy. ^f3
  > the summary will inform you if the files to upload have already been uploaded by a previous deploy with the same commits.
- [ux/progress] The log ends with success, failure or cancellation; summary takes the log's highlights. ^f4
  > details about the success, failure, or cancellation of the deploy
  > For any successful deploy, highlights from the deploy log will be included in the [deploy summary](https://docs.netlify.com/deploy/deploy-overview#deploy-summary).
- [ux/progress] Failed deploys get a "Why did it fail?" diagnosis button. ^f5
  > Getting a diagnosis and suggested solution with **Why did it fail?** doesn’t consume any credits.
- [ux/progress] Line and range links by line number; copy whole log. ^f6
  > You can also generate a shareable URL for a single log line or a range of lines.
