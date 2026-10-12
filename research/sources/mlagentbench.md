---
title: 'MLAgentBench: Evaluating Language Agents on Machine Learning Experimentation'
url: https://arxiv.org/html/2310.03302
kind: paper
commit:
for: [llm-experiment-agent]
looked: 2026-10-12
depth: docs (sections 1-4, appendices A-D)
relevance: high
grade: B/fair
description: Stanford benchmark of 13 ML experimentation tasks with a ReAct-style research agent (file actions, LM-backed Understand/Edit actions, research plan and fact check in every step)
---
# MLAgentBench: Evaluating Language Agents on Machine Learning Experimentation

Why: which action set and per-step memory help an LLM agent run ML experiments, and how
it fails.

## Assessment

- Evidence: B. Stanford (Huang, Vora, Liang, Leskovec), ICML 2024; 13 tasks, 8 runs
  per agent and model, success = 10% gain over starter code. Widely reused (MLE-bench
  runs its agent as "MLAB"). Models are 2023-24 (Claude 3 Opus best).
- Reasoning: fair. Compares its agent with AutoGPT and LangChain, but has no ablation
  of each action or of the plan and fact-check fields; their value is shown by
  examples only. Failure categories counted on CIFAR-10 runs only.
- Interests: authors' own agent against baselines.
- Weigh: the action set and the plan/fact-check format are a usable template; that
  they help is (claim) beyond the framework comparison. Tasks run in minutes, close to
  our scale.

## Findings

- [lab] Action set: list, read, write, append, copy files, inspect script lines, undo
  edit, execute script, final answer; plus three compound LM-backed actions: Understand
  File, Edit Script, Edit Script Segment. `2.2.1`, `Table 1` ^f1
  > actions that are available in the environment include file system operations (read, write, append, copy, edit, undo edit), execution of any arbitrary Python script, and a final answer declaration action.
  > The last three are compound actions that is composed of multiple primitive actions and LM calls.
- [lab] Understand File hands a file and a query to a separate LM call that returns a
  summary with line numbers, keeping big files out of the main context. `2.2.1` ^f2
  > This action takes a file name and a short query as input e.g. what is the model architecture, reads the file, and calls an LM to summarize it based on the short query.
  > It then returns the retrieved and summarized information with detailed references to line numbers.
- [lab] Edit Script takes a natural-language instruction, a sub-LM writes the edit, and
  the agent sees the diff; the segment variant edits only a line range, for big
  codebases. `2.2.1`, `Table 1` ^f3
  > It first reads the file, calls an LM to perform an edit of a file given a short edit instruction from the main agent, then writes the modified version to the file with the given file name.
  > This is particularly helpful when the task involves manipulating a large codebase
- [lab] Memory is the last 3 steps plus a structured response each step: Reflection,
  Research Plan and Status, Fact Check, Thought, Action; the authors call the response
  format the most important part. `3`, `3.1` ^f4
  > the last 3 steps taken including
  > The most important component of our agent is specifying the response format
  > the thought consists of a Reflection, Research Plan and Status, Fact Check, Thought, and then Action and Action Input.
- [lab] Fact Check targets a common failure: claiming an improvement from an edit that
  was never run. It does not fully stop hallucinated results (20% of Claude v1 runs).
  `3.1`, `D.2` ^f5
  > One common failure mode during our prelimiary experiments is that the model hallucinates improvement after modifying the file without ever executing it.
  > Of course, this does not guard against hallucination completely.
  > this happens to 20% of the runs for Claude-1
- [lab] Against other frameworks on the same models, their agent averaged 37.5%
  (Claude 3 Opus) vs AutoGPT 13.5% and LangChain ReAct 33.7%; the simpler LangChain
  agent was close because it broke the submission format less. `A`, `4.1` ^f6
  > We note that LangChain with Claude v3 is very competitive to our method, partially because it is simpler so that the agent does not attempt to change the submission format incorrectly.
- [lab] Running longer usually made results worse, except for Claude 3 Opus: agents
  regress in later steps. `4.2`, `Figure 3` ^f7
  > We can see that running longer generally degrades the performance except for Claude v3 Opus.
- [lab] Failure modes on CIFAR-10: hallucinated results, bad early plans that are hard
  to recover from, invalid response JSON, broken submission format, too-small gains.
  `4.2` ^f8
  > Hallucination, where the agent claims to know something or fabricates some results such as claiming performance increase without even executing any edits in the training script.
  > Most of these bad plans occur in the initial steps and recovery is difficult thereafter.
- [lab] Over-ambitious edits that stall in debugging hit 40% of Claude v1 runs; the
  plan field did not prevent it, and reflection can turn into reflecting without
  acting. `D.1` ^f9
  > one common failure mode that this entry fails to prevent is when the agent plans to carry out too complex an edit and becomes stuck with debugging, which occurs in 40% of the runs for Claude v1.0
  > this also makes the agent prone to just keep reflecting without actually performing actions.
- [lab] The task spec must state which file and metric are scored and its direction:
  an agent tried to raise SMAPE, not knowing lower is better. `D.3` ^f10
  > The problem description needs to clearly specify what file and what metrics will be evaluated.
  > our agent tried to increase SMAPE score on amp-parkinsons-disease-progression-prediction dataset, since it does not know that SMAPE is the lower the better
- [lab] Budget: 8 runs per task, at most 50 actions and 5 hours each; success ranged
  from 100% on old datasets to 0% on recent Kaggle tasks. `4`, abstract ^f11
  > we allow a maximum of 50 actions in the environment and a maximum time of 5 hours
  > they span from 100% on well-established older datasets to as low as 0% on recent Kaggle challenges created potentially after the underlying LM was trained.
- [lab] Cost: a few dollars per run, but at a 26% success rate the expected cost per
  solved task was $231, so reliability matters more than per-run cost. `4.3` ^f12
  > However, with the low average success rate of 26%, the expected cost to accomplish a task becomes $231, making reliability important for the usability of the agents.
- [lab] Checked, not there: no ablation of individual actions (Understand File, Edit
  Script) or of the plan and fact-check fields. ^f13

## Read

- Abstract, 1, 2.2, 3, 4, appendices A-D: fully

## Not read

- 2.4 task details, 5 related work, appendix F full trace
