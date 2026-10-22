---
title: Automation That Screams Joy (TigerBeetle blog, matklad, 2026)
url: https://tigerbeetle.com/blog/2026-04-14-automation-screams-joy
kind: article
commit:
for: [zig-build]
looked: 2026-10-22
depth: docs (whole post)
relevance: medium
grade: B/fair
description: project automation in the repo and in the project language (Zig), self-deploying from main via a clone-build-run loop
---
# Automation That Screams Joy (TigerBeetle blog, matklad, 2026)

Why: Tiger Style says scripts in Zig; this is how TigerBeetle runs its fuzz fleet that
way. meiolol keeps many deploy/*.sh scripts.

## Assessment

- Evidence: B. TigerBeetle's own fuzzing fleet (CFO); first post of a series.
- Reasoning: fair; problems of the old Go service named; costs (verbosity) admitted.
- Interests: none.
- Weigh: the shell loop it praises is itself bash; the point is minimal bootstrap,
  logic in Zig.

## Findings

- [zig/build] Automation lives in the main repo (`./src/scripts`) and in the project
  language, so every developer can find, change and deploy it. ^f1
  > _First_, we make sure that automation lives in the same repository as the main project.
  > _Second_, we make sure that automation is implemented in the same language as the project itself.
- [zig/build] Cost of Zig over bash is verbosity, closed by a helper library; gains
  are no context switch, no sed dialects, no ShellCheck. ^f2
  > In return for a slight increase in verbosity you remove the need to context switch, stop worrying about semantic differences between BSD and GNU sed, and remove the need to set up ShellCheck
- [zig/build] Auto-deploy: deployed automation is a tiny loop that clones main, fetches
  the pinned Zig, builds and runs for 30 minutes, then repeats. ^f3
  > The invariant you maintain is that the version of automation deployed matches the current tip of the main branch.
  > ./zig/zig build -Drelease scripts -- cfo --timeout=30m

## Read

- Whole post.
