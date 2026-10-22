---
title: Scalar Select Anti-Pattern (matklad, 2025-05-14)
url: https://matklad.github.io/2025/05/14/scalar-select-aniti-pattern.html
kind: article
commit: 
for: [zig-perf, zig-api-design]
looked: 2026-10-22
depth: docs (whole post)
relevance: medium
grade: B/fair
description: Event loops should pull all ready events as a batch to prioritise, apply backpressure, eliminate and coalesce, instead of one event per select
---
# Scalar Select Anti-Pattern (matklad, 2025-05-14)

Why: batching in event loops. Pseudo-code; caused by TigerBeetle PR 2970.

## Assessment

- Evidence: B. Expert, refactored several services this way.
- Reasoning: fair. Four concrete benefits; no measurements.
- Interests: none.
- Weigh: applies to meiolol's crawler and app event loops.

## Findings

- [zig/perf] A one-event-at-a-time loop picks an arbitrary ready event although several
  are usually waiting after processing the last. ^f1
  > Our “scalar select” will pick an arbitrary one, and that might create a lot of overhead.
- [zig/perf] With a batch you can prioritise (writes over reads over accepts), exert
  selective backpressure, eliminate superseded events and coalesce. ^f2
  > The rule-of-thumb priority is writes over reads over accepts (of new clients).
- [zig/perf] Always be batching: `batch_stream` waits for one event, then takes all
  available non-blocking; under load batches grow and cost grows sublinearly. ^f3
  > Under low load, we’ll be getting singleton batches. But as the load increases, the batch size will grow, increasing our load sublinearly!

## Read

- Whole post.

## Not read

- TigerBeetle PR 2970: reader "tigerbeetle".
