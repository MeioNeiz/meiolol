---
title: "arbolitoloco1/mwcleric (empty_string_fix branch): cargo retry"
url: https://github.com/arbolitoloco1/mwcleric/tree/empty_string_fix
kind: project
commit: 70125d21bcdaa92317def7c89f5c194a73b212ba
for: [leaguepedia-daily-fetch]
looked: 2026-10-26
depth: code (clients/cargo_client.py)
relevance: medium
grade: B/fair
description: The mwcleric fork Leaguepedia recommends: on ratelimited it relogs and retries with exponential backoff (0, 10, 30 s by default)
---
# arbolitoloco1/mwcleric (empty_string_fix branch): cargo retry

Why: what backoff does the recommended client use on `ratelimited`?

## Assessment

- Evidence: B. Recommended by a Leaguepedia admin ([[leaguepedia-cargo-ratelimits#^f3]]).
- Reasoning: fair (comments explain the schedule).
- Interests: none.
- Weigh: shows practice, not the server's limits.

## Findings

- [data] On `ratelimited` (or `permissiondenied` when logged in) it logs in again and retries up to 3 times, sleeping (2^n - 1) x 10 s: 0, 10, 30 s. `mwcleric/clients/cargo_client.py` ^f1
  > if e.code not in ['ratelimited', 'permissiondenied'] or self.max_retries == 0:
  > time.sleep((2 ** retry_count - 1) * self.retry_interval)
  > # default interval is 10, default retries is 3

## Read

- `raw/mwcleric-arbolito/mwcleric/clients/cargo_client.py`.

## Not read

- Rest of the client.
