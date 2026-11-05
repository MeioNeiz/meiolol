---
title: "Claude Code docs: Run parallel sessions with worktrees"
url: https://code.claude.com/docs/en/worktrees.md
kind: docs
commit: 
for: [parallel-build-capacity]
looked: 2026-11-05
depth: docs (intro, start, environment, subagent isolation)
relevance: medium
grade: B/fair
description: Official docs for --worktree: each session a separate checkout and branch, so edits don't collide; environment set up per worktree
---
# Claude Code docs: Run parallel sessions with worktrees

Why: what isolation does Anthropic recommend for parallel sessions, and what does it
cost?

## Assessment

- Evidence: B. Vendor docs for a shipped feature
- Reasoning: fair. Describes mechanics; costs only implied (fresh checkout, setup)
- Interests: vendor
- Weigh: worktrees isolate files, nothing else; build outputs, caches and machine
  capacity stay shared or get duplicated

## Findings

- [devflow/agents] A worktree is a separate directory and branch sharing history and
  remote; one per session lets parallel sessions edit their own copy. ^f1
  > Running each Claude Code session in its own worktree gives it a separate copy of the files to edit, so one session can build a feature while a second fixes a bug.
- [devflow/agents] Worktrees isolate file edits only; other tools (subagents, messaging)
  handle splitting and coordination. ^f2
  > Worktrees are one of several ways to run Claude in parallel. They isolate file edits.
- [devflow/agents] Each worktree is a fresh checkout that needs its own environment
  setup (dependencies, gitignored files via .worktreeinclude). ^f3
  > A worktree is a fresh checkout, so initialize your development environment there
- [devflow/agents] Subagents can each get a worktree (`isolation: worktree`) so parallel
  edits don't conflict. ^f4
  > Subagents can run in their own worktrees so parallel edits don't conflict.
- [devflow/agents] (inferred) For us: a worktree per session would give each its own
  build directory (more total build work, not less), and merges replace live
  same-checkout conflicts; it does nothing for the 3-slot CPU limit. ^f5
- [devflow/agents] Checked, not there: nothing on build caches, CPU or CI sharing between
  worktrees. ^f6

## Read

- intro to "Isolate subagents with worktrees"

## Not read

- cleanup, resume, non-git hooks, troubleshooting
