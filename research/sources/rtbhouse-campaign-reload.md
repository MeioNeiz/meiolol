---
title: 'RTB House 2026: Rethinking Campaign Reload (snapshot builder for bidders)'
url: https://techblog.rtbhouse.com/rethinking-campaign-reload/
kind: article
commit: 
for: [fast-deploy-data-servers]
looked: 2026-10-15
depth: docs (whole post)
relevance: high
grade: B/strong
description: RTB House engineering blog (Jul 2026); bidders used to each build in-memory campaign structures from PostgreSQL (15-40+ min); a separate Snapshot Builder job now builds them once per code version (keyed by commit hash), bidders fetch and swap the serialised snapshot in seconds
---
# RTB House 2026: Rethinking Campaign Reload (snapshot builder for bidders)

Why: the closest match to our shape: a latency-critical server whose in-memory
structures are built from a SQL database, slow on loaded machines, rebuilt on every
start.

## Assessment

- Evidence: B. First-hand engineering report from a large production system
  (thousands of bidders, tens of billions of requests a day), with before/after
  numbers; not independently checked.
- Reasoning: strong. Explains the version-coupling choice and its cost, the rejected
  alternative (one snapshot for all versions), migration modes with fallback, and bugs
  found on the way.
- Interests: company tech blog (recruiting tone), no product being sold.
- Weigh: their scale problem (thousands of readers hitting the DB) is not ours; the
  per-commit snapshot keying and the fallback modes transfer directly.

## Findings

- [ops] Before: every bidder loaded PostgreSQL and built hot-path structures itself
  while serving; ~15 min on good machines, 30-40+ min on slow or loaded ones. ^f1
  > On a well-provisioned machine, this reload took on the order of 15 minutes – but on a slower or more loaded machine it could stretch to 30–40 minutes or more.
- [ops] Building is expensive because the structures are shaped for microsecond access,
  not because of the DB read. ^f2
  > These structures are pre-computed and shaped for microsecond access on the hot path, which is precisely what makes building them expensive.
- [ops] Fix: a separate short-lived Snapshot Builder job builds the structures once,
  serialises (Kryo + gzip) to object storage; servers fetch and atomically swap it in
  within seconds. ^f3
  > Bidder instances no longer compute anything themselves; they simply fetch the latest snapshot and atomically swap it into their in-memory state within seconds.
- [ops] Snapshots are keyed by commit hash and time; every server build has a matching
  builder build, so a server only loads snapshots built by its own code version. ^f4
  > This means a bidder running a given code version will only ever load a snapshot built by the exact same version of the construction logic.
- [ops] Rejected: one snapshot format shared across versions, which would force
  additive-only changes; they build a snapshot per active version instead and call the
  extra builds cheap. ^f5
  > Supporting multiple bidder versions off a single snapshot would have required enforcing a lowest-common-denominator structure across all active versions
  > the compute cost of running a Snapshot Builder job is low, and the simplicity gained far outweighs the overhead.
- [ops] Rollout had a mode that loads a snapshot but falls back to the old in-process
  build if none is found or loading throws. ^f6
  > bidders fetch from the object storage but fall back to in-process if no snapshot is found or an exception is thrown.
- [ops] Bugs found on the way: a serialisation bug leaving fields null after load, and a
  deploy that built server and builder from different commits, breaking the coupling. ^f7
  > a commit landing mid-deploy could leave the Bidder and SnapshotBuilder built from different hashes – breaking the version-coupling guarantee the entire design relied on.
- [ops] Result: data freshness SLO under 20 min everywhere, startup 30-40% faster at
  median and p95 (a fetch replaces the build), up to 1% CPU per bidder freed. ^f8
  > Bidder startup time improved by roughly 30–40% at the median and p95: the expensive in-process computation no longer happens at startup, replaced by a snapshot fetch.
- [ops] (inferred) For meiolol: a code deploy that changes the derived structures needs
  a new snapshot, so "snapshot file" only removes the rebuild from deploys that keep
  the format. Keying the file by a format version (as our curves files already carry)
  and falling back to rebuild on mismatch gives fast restarts for most deploys and a
  correct slow path for the rest. ^f9

## Read

- Whole post.

## Not read

- Their microservices migration post (linked).
