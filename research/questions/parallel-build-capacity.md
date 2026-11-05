---
status: answered
priority: soon
area: ops
tags: [devflow, devflow/queue, devflow/select, devflow/cache, devflow/agents]
description: What is the best way to run many parallel coding agents against limited build and CI capacity on one Mac (merge queues, batching, test selection, caches and offloading, slot scheduling, team size)?
---
# What is the best way to run many parallel coding agents against limited build and CI capacity on one Mac (merge queues, batching, test selection, caches and offloading, slot scheduling, team size)?

Feeds: docs/plan/how-we-work.md (team size, push mode), docs/dev-flow.md (slots, pushes), docs/plan/build-speed.md BS3; report data/team/2026-11-05-meionotes/buildflow-research.md

## Answer

Our ci has slowed from ~30 s to a ~230 s median and holds the whole 3 slot pool (C1). The
Mac is swapping, not just short of cores (C2), and the box sits mostly idle (C3). Zig has no
remote cache, so the cheap capacity win is moving whole builds, ci first, onto the box
(C11, C3). Zig's cache is built for concurrent use and ignores the checkout's location, but
it keeps only the last contents per path set, so the clean ci tree and the working tree
evict each other (C9, C10). Give ci its own cache dir. Queue waits blow up near saturation,
and 30 s checks stuck behind a 4 min exclusive ci are the worst case (C12, C13). A short
lane fixes that, though agents waiting on their own builds blunt the gain (C14). Merge
queues batch whatever arrived during the last run and split a failed batch, so the cost is
logarithmic; push.sh walks down the batch one ci at a time (C5, C6, C7). Batching pays
under ~40% failure, and today's was 30%, half of it from the cache race (C8, C4). Test
selection beyond Zig's own caching gains little at our size (C15). On team size, sources
say 3-5 agents, with review the limit beyond that (C16, C17). With current capacity,
~5 builders is right; with ci and tests on the box, 6-7 (C18). Report:
data/team/2026-11-05-meionotes/buildflow-research.md.

## Claims

- C1: Pre-push ci went from a 30 s median (17 Oct) to 192-232 s (4-5 Nov), all on the Mac, each run holding all 3 slots; warm and quiet it is still 72-90 s. for: [[meiolol-buildflow-logs#^f1]], [[meiolol-buildflow-logs#^f2]], [[meiolol-buildflow-logs#^f4]]
- C2: The Mac is memory-bound: 16.5 of 17.4 GB swap in use, load 13-15 on 10 cores, Chrome the top CPU user. for: [[meiolol-buildflow-logs#^f6]], [[meiolol-buildflow-logs#^f7]]
- C3: The box has ~12 idle vCPU and 51 GB free, but only 9.5 GB free on its root disk. for: [[meiolol-buildflow-logs#^f8]]
- C4: 30% of 5 Nov's ci runs failed, 3 of 6 from one cache race. for: [[meiolol-buildflow-logs#^f3]]
- C5: Merge queues advance main only to a tested merged result. for: [[graydon-not-rocket-science#^f3]], [[bors-ng-readme#^f4]], [[github-merge-queue-docs#^f1]], [[zuul-gating#^f1]]
- C6: Batch size comes from what queues during one run (bors), or from N or T (GitHub), not a fixed timer alone. for: [[bors-ng-readme#^f3]], [[github-merge-queue-docs#^f3]]
- C7: A failed batch is split: halves cost O(E log N) runs; at 4 or fewer, testing each alone is cheaper. for: [[bors-ng-readme#^f5]], [[bors-ng-readme#^f8]], [[fallahzadeh-parallel-batch-2023#^f5]]
- C8: Batching pays below ~40% failure, and the scarcer the machines the bigger the batch. for: [[fallahzadeh-parallel-batch-2023#^f2]], [[fallahzadeh-parallel-batch-2023#^f8]] against: [[uber-submitqueue-2019#^f5]]
- C9: Zig 0.17 keys files relative to the build root; identical trees at different paths share. for: [[zig-017-build-cache#^f1]], [[zig-017-build-cache#^f5]]
- C10: One manifest per path set, last contents only: trees with differing files evict each other in one cache dir. for: [[zig-017-build-cache#^f3]], [[zig-017-build-cache#^f4]]
- C11: Zig has no remote cache or execution protocol; offloading means whole builds on another host. for: [[zig-017-build-cache#^f10]], [[bazel-remote-rules#^f2]]
- C12: Queue wait grows as rho/(1-rho) times job-size variability. for: [[harchol-balter-practitioner-queueing#^f1]], [[kingman-formula-wikipedia#^f2]]
- C13: Shortest-first (3 buckets suffice) or a short-job lane cuts mean wait; long jobs barely suffer. for: [[harchol-balter-practitioner-queueing#^f4]], [[harchol-balter-practitioner-queueing#^f7]], [[harchol-balter-practitioner-queueing#^f5]]
- C14: In closed systems size-based scheduling matters much less. for: [[harchol-balter-practitioner-queueing#^f10]]
- C15: Safe test selection comes from the build dependency graph; learned selection needs a periodic full run. for: [[machalica-pts-2019#^f3]], [[machalica-pts-2019#^f5]], [[memon-tap-2017#^f3]]
- C16: Recommended team: 3-5 agents; cost grows linearly, returns diminish. for: [[claude-code-agent-teams-docs#^f3]], [[claude-code-agent-teams-docs#^f2]], [[anthropic-multi-agent-research#^f5]]
- C17: Review, not agent count, is the human bottleneck; coding parallelises less than research. for: [[willison-parallel-agents#^f1]], [[anthropic-multi-agent-research#^f4]], [[cognition-dont-build-multi-agents#^f2]]
- C18 (inferred): ~5 builders fit 3 Mac slots; more only once ci and tests run on the box. from: C1, C3, C12, C16

## Disagreements

- Path keying: build-tree.sh says a fresh checkout per run rebuilt everything (real
  tree, Oct); zig-017-build-cache found path-independent hits on a toy project. Settle by
  timing a second fixed tree on the real repo (a Run step taking an absolute path would
  key on it).
- Concurrency: Zig's cache is designed for concurrent builds (zig-017-build-cache ^f6),
  yet ci failed 3 times with island .wasm FileNotFound under load. Suspects outside Zig's
  locks: zig-cache-prune.sh (pgrep check then mv), or ci and working tree evicting each
  other's outputs (C10). A private ci cache dir removes both.
- Batch size: Fallahzadeh favours large adaptive batches; Uber found large batches split
  often and made waits unpredictable at 500 changes an hour. We run ~5-15 an hour.

## Open

- Slots keep no history: queue waits are samples until they are logged.
- ci time on the box (Haswell, 2014) is unmeasured; gpu-box was 51 s idle.
- Najafi and Beheshtian optimal batch size maths (leads).
