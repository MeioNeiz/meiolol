---
title: GitHub Acceptable Use Policies (2026)
url: https://docs.github.com/en/site-policy/acceptable-use-policies/github-acceptable-use-policies
kind: docs
commit:
for: [free-hosting-storage]
looked: 2026-10-11
depth: docs (sections 4, 9, 10)
relevance: high
grade: A/fair
description: GitHub's AUP: excessive bandwidth may lead to suspension, throttled file hosting or deleted repos; no excessive automated bulk activity
---
# GitHub Acceptable Use Policies (2026)

Why: can meiolol use GitHub to store backups or data, and what are the limits?

## Assessment

- Evidence: A. GitHub's own docs, current on 2026-10-11.
- Reasoning: fair.
- Interests: vendor (platform terms).
- Weigh: binding limits and policy wording.

## Findings

- [ops] [policy] GitHub may suspend accounts, throttle file hosting or, after notice,
  delete repos that place undue strain on its infrastructure. ^f1
  > If we determine your bandwidth usage to be significantly excessive in relation to other users of similar features, we reserve the right to suspend your Account, throttle your file hosting, or otherwise limit your activity until you can reduce your bandwidth consumption.
  > We also reserve the right—after providing advance notice—to delete repositories that we determine to be placing undue strain on our infrastructure.
- [ops] [policy] The AUP points to the large-files page for acceptable object storage
  use in repositories. ^f2
  > For guidance on acceptable use of object storage in repositories, refer to
- [ops] [policy] No excessive automated bulk activity or undue burden by automated means. ^f3
  > using our servers for any form of excessive automated bulk activity, to place undue burden on our servers through automated means
- [ops] Checked, not there: no explicit ban on backups or CDN use by name; the limits
  come through bandwidth, bulk activity and the large-files guidance. ^f4

## Read

- sections on bandwidth, bulk activity, advertising

## Not read

- linked per-topic policy pages
