---
status: decided
priority: now
area: ops
tags: [ops, render]
description: How do servers that hold large in-memory data built from a database deploy new code quickly, without rebuilding that data on every restart?
decision: docs/plan.md#site-build-and-deploy-2026-10-12-owner-the-site-session
---
# How do servers that hold large in-memory data built from a database deploy new code quickly, without rebuilding that data on every restart?

Feeds: how meiolol-render loads its data and how a deploy swaps it (docs/hosting.md
"Rendering on request", docs/plan.md "Site build and deploy"). On 14-15 Oct every
render-swap timed out: each load rebuilt every view from the 8.4 GB meiolol.db (2-13
min, up to 105 min on a busy disk) beside the old renderer's own reload.

## Answer

Systems that serve large derived data take the build out of the serving process: a
batch job writes an immutable file and servers load or mmap it in seconds (C1). The
restart cost is turning stored rows into the in-memory form, not the disk read (C2),
which is exactly meiolol's case (random sqlite reads into tallies). The files are tied
to the code that wrote them, with a fallback to the full build when they don't match
(C3). Shared-memory handover (Scuba) gets the same speed with more machinery and still
rebuilds after a crash (C5); a second warm copy doubles memory (C7). mmap starts
instantly but serves cold (C4); reading the file into the heap costs seconds.

For meiolol (C6): the web loop's `meiolol site --views` writes every view to
data/views.bin after each upload, the renderer reads it at start and on reload, and a
fingerprint of the types decides compatibility, else the database load as before. A
blue/green swap then overlaps for seconds, not the whole rebuild.

## Claims

- C1: Mature systems with large derived in-memory data build it in a batch job into an immutable file that servers load or mmap in seconds. for: [[voldemort-readonly-2012#^f2]], [[voldemort-readonly-2012#^f8]], [[rtbhouse-campaign-reload#^f3]], [[sparkey#^f1]]
- C2: The main restart cost is converting stored rows into the in-memory form, not disk I/O; a file near the memory layout removes it. for: [[fb-fast-restarts-2014#^f1]], [[fb-fast-restarts-2014#^f13]], [[rtbhouse-campaign-reload#^f2]]
- C3: Prebuilt data is keyed to the code or format that wrote it, with a fallback to the full build on a mismatch or a failed load. for: [[rtbhouse-campaign-reload#^f4]], [[rtbhouse-campaign-reload#^f6]], [[fb-fast-restarts-2014#^f9]]
- C4: An mmapped file starts instantly but serves slowly until warm; reading it through before taking traffic avoids that, and mmap suits read-only data that fits in memory. for: [[manticore-startup-mmap#^f2]], [[manticore-startup-mmap#^f6]], [[crotty-mmap-2022#^f6]] against: [[crotty-mmap-2022#^f3]]
- C5: Shared-memory handover needs a valid bit, a version and its own memory format, and still rebuilds after any crash. for: [[fb-fast-restarts-2014#^f9]], [[fb-fast-restarts-2014#^f7]]
- C6 (inferred): For meiolol, a views file written by the web loop and read by the renderer makes a deploy a code swap of seconds, with the database load as the fallback. from: C1, C2, C3
- C7: Keeping a second warm copy to cover upgrades doubles memory and needs sync code; Scuba rejected it. for: [[fb-fast-restarts-2014#^f3]]
- C8: A new process should be fully ready before it takes the socket over; Envoy's hot restart does this. for: [[envoy-hot-restart#^f2]]

## Disagreements

mmap (C4): the CIDR 2022 paper argues against it for databases, mainly for data larger
than memory and writes; it accepts read-only data that fits. Not tested here: we read
the file into the heap.

## Open

- Measured 15 Oct on the busy box: views.bin 148 MB, written in 72 min, read in 14 s,
  swap 16 s. The write is still the old load's cost; making it cheaper is separate.
- Whether a data-code change should also bump the fingerprint (RTB keys by commit
  hash); today the next web loop round refreshes it within minutes of a deploy.
- Leads: LinkedIn Venice (why build-and-push was replaced), Glean's code reload.
