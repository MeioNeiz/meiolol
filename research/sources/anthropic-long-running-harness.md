---
title: Effective harnesses for long-running agents (Anthropic, 2025)
url: https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents
kind: article
commit: 
for: [agent-ml-practice]
looked: 2026-10-13
depth: docs (whole post)
relevance: high
grade: B/fair
description: Anthropic engineering post (Nov 2025) on keeping Claude coding agents productive across many context windows: initializer agent, JSON feature list, progress file, git commits, start-of-session checks
---
# Effective harnesses for long-running agents (Anthropic, 2025)

Why: which harness features keep a Claude Code style agent reliable across sessions
(progress files, state handoff, verification), for the meiolol lab agent.

## Assessment

- Evidence: B. First-hand report from the model vendor's own teams, one task type (a
  claude.ai clone web app); no numbers, no ablation, failure modes described
  qualitatively.
- Reasoning: fair. Each mechanism is tied to an observed failure mode; says plainly
  it is "one possible set of solutions" and untested outside web apps.
- Interests: vendor (promotes the Claude Agent SDK), but the advice is generic.
- Weigh: trust the failure modes (they match ours: half-done work, early "done",
  unverified claims). The JSON-vs-Markdown point is an observation, not measured.

## Findings

- [lab] Compaction alone is not enough across context windows; the agent tries to
  one-shot and runs out of context mid-feature, leaving the next session guessing. ^f1
  > However, compaction isn’t sufficient.
  > the agent tended to try to do too much at once—essentially to attempt to one-shot the app
  > leaving the next session to start with a feature half-implemented and undocumented
- [lab] A second failure: a later session sees progress and declares the job done. ^f2
  > a later agent instance would look around, see that progress had been made, and declare the job done
- [lab] Fix: a first session writes an init.sh, a claude-progress.txt log of what agents
  did, and an initial git commit; later sessions read progress file plus git history. ^f3
  > an `init.sh` script, a claude-progress.txt file that keeps a log of what agents have done, and an initial git commit
  > The key insight here was finding a way for agents to quickly understand the state of work when starting with a fresh context window, which is accomplished with the claude-progress.txt file alongside the git history.
- [lab] A structured list of 200+ requirements, all initially "failing", which agents may
  only edit by flipping a passes field; JSON because the model overwrites it less often
  than Markdown. ^f4
  > These features were all initially marked as “failing”
  > We prompt coding agents to edit this file only by changing the status of a passes field
  > we landed on using JSON for this, as the model is less likely to inappropriately change or overwrite JSON files compared to Markdown files
- [lab] One feature per session, then commit with a descriptive message and write a
  progress summary, so git can revert bad changes. ^f5
  > asked to work on only one feature at a time. This incremental approach turned out to be critical
  > ask the model to commit its progress to git with descriptive commit messages and to write summaries of its progress in a progress file
- [lab] Agents mark work complete without end-to-end checks; giving them a real testing
  tool (browser automation) dramatically improved results. ^f6
  > Claude’s tendency to mark a feature as complete without proper testing
  > Providing Claude with these kinds of testing tools dramatically improved performance
- [lab] Each session starts with a fixed routine: pwd, read progress and git log, pick
  the top unfinished item, run init.sh and a basic end-to-end test before new work. ^f7
  > Read the git logs and progress files to get up to speed on what was recently worked on.
  > run through a basic end-to-end test before implementing a new feature
- [lab] Checked, not there: no measurement of how much each mechanism helped, and
  nothing on ML experiments; the post names scientific research only as future work. ^f8
  > It’s likely that some or all of these lessons can be applied to the types of long-running agentic tasks required in, for example, scientific research or financial modeling.
- [lab] (inferred) For meiolol: the lab's runs.tsv is the equivalent of the feature
  list, but a status per planned experiment (queued, running, failed, done) in a
  machine-written JSON file the agent cannot rewrite would stop "already tried" and
  "done" errors; a session-start smoke run plays init.sh's part. ^f9

## Read

- Whole post, including the failure-mode table.

## Not read

- `github.com/anthropics/claude-quickstarts/tree/main/autonomous-coding`: the code
  behind the post (prompts, progress file format).
