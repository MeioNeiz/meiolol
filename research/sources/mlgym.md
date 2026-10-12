---
title: 'MLGym: A New Framework and Benchmark for Advancing AI Research Agents'
url: https://arxiv.org/html/2502.14499
kind: paper
commit:
for: [llm-experiment-agent]
looked: 2026-10-12
depth: docs (sections 3, 5, 7, 8, appendix A)
relevance: high
grade: B/fair
description: Meta's Gym environment and 13-task benchmark for AI research agents; SWE-Agent style tools, a validate command, literature search and an embedding memory module
---
# MLGym: A New Framework and Benchmark for Advancing AI Research Agents

Why: which tools (memory, validation, search) an ML research agent gets, which it uses,
and how runs fail.

## Assessment

- Evidence: B. Meta, February 2025; 13 tasks, 5 models, 4 seeds each, 220
  trajectories in the failure analysis. One scaffold only (SWE-Agent adaptation), so it
  compares models, not tools.
- Reasoning: fair. Clear tool design and failure counts; the memory module's benefit
  is asserted from two example figures, and the module was not used in the main runs.
- Interests: Meta's framework; Llama is among the models compared (and does not win).
- Weigh: trust the tool list, the step budget and the failure and action breakdowns.
  Treat "memory helps" as (claim): no ablation numbers. Note the validate command
  reports test-set metrics as often as the agent likes.

## Findings

- [lab] Tools: SWE-Agent search (search_dir, search_file, find_file), a windowed file
  viewer, line-range editor with lint, validate, submit; extended tools are literature
  search, PDF parsing and a memory module. `3.5`, `Table 2` ^f1
  > we extend the commands for search, navigation, file viewer, file editor and context management with our permission management system and introduce new commands for literature search and a memory module.
- [lab] Main experiments used only the SWE-Agent tools and validate; the literature
  search and memory tools were not part of the measured runs. `3.5` ^f2
  > For all the experiments presented in this paper, the agent only uses the SWE-Agent tools and validation command.
- [lab] Memory module: memory_write stores text with embeddings and tags as JSON;
  memory_read returns the top matches by cosine similarity; memory tags and record
  count go in the system prompt. `3.5` ^f3
  > The memory\_write function allows the agent to store key insights and effective configurations by saving text data along with its corresponding embeddings and tags in JSON format.
  > we added the state of the memory to the system prompt (memory tags and number of records) so that the agent is aware of the type of data stored.
- [lab] (claim) Without memory, long runs outgrow the context and the agent forgets
  older experiments, iterating only on recent configs; with it, it retrieves the best
  config and continues. Shown by two example figures, no numbers. `3.5`, `A.5` ^f4
  > Without the memory module, the agent’s trajectory can become longer than the model’s context length, thus not being able to retrieve the best configuration, effectively forgetting older experiments and only being able to locally iterate on recent configurations.
  > the agent using the memory module to store and retrieve specific experimental results and use them to submit the best possible model.
- [lab] The authors' own ideas for better memory: structured (hierarchical or
  relational) records, or a sub-agent that curates entries. `3.5` ^f5
  > one possible direction would be to introduce a more structured memory format, such as hierarchical or relational models
  > using a sub-agent that will automatically manage the memory by selecting important insights, removing unnecessary entries, and updating the memory.
- [lab] Guards by permission: datasets copied read-only, evaluation script read-only,
  and tools return feedback text on a forbidden edit instead of failing silently.
  `3.3`, `3.4`, `3.5` ^f6
  > This ensures that the agent cannot change the dataset files, which is important for reproducibility and cheating prevention.
  > the evaluation script is read-only for the LM agent, so while it can inspect the evaluation format, it cannot modify the script to change the evaluation logic.
  > if agent tries to edit the evaluation script (which is marked as read-only), the edit tools will output a feedback string instead of failing silently.
- [lab] validate runs the evaluation and returns the current test-set score, usable
  any number of times during a run. `3.5` ^f7
  > the validate command can be used as many times as needed during the run to get the current performance on the test set.
- [lab] Budget: 50 steps per run, a rolling window of the last five interactions, one
  command per step, no interactive sessions, and a per-task timeout on training
  commands. `5.1`, `5.2` ^f8
  > A single agent run is limited to 50 steps (i.e. interactions with the environment), after which the agent is terminated and the last codebase state is autosubmitted.
  > A processor maintains a rolling window with the five most recent interactions (action and observation)
  > to control the runtime of the agent and prevent it from simply increasing the number of parameters in the model, we set a task specific timeout for the training commands.
- [lab] Headline: agents beat baselines mostly by tuning hyperparameters, not new ideas.
  abstract ^f9
  > We find that current frontier models can improve on the given baselines, usually by finding better hyperparameters, but do not generate novel hypotheses, algorithms, architectures, or substantial improvements.
- [lab] Best Attempt vs Best Submission: the final submission can be worse than the
  best intermediate attempt; falling back to the best one is a separate skill
  measured apart. `7.1` ^f10
  > Best Submission indicates the LLM agent’s capability to produce a valid final solution for a task as well as the ability to remember to fall back to the best intermediate solution in case some experiments don’t pan out.
- [lab] Failure: evaluation errors (missing or malformed submission artefacts) were 75%
  of termination errors; cost limit was second for the best models. `7.4.1` ^f11
  > almost all models encounter Evaluation Error and is generally the most frequent final error, accounting for 75% of all termination errors.
  > Cost Limit is the second most frequent error encountered by Claude-3.5-Sonnet, Gemini-1.5-Pro and OpenAI O1-Preview
- [lab] Action mix: edits are half of all actions, search 1%; Python runs and validate
  are used steadily; some models submit as early as step 5. `7.4.2` ^f12
  > File commands such as Edit and View are one of the most frequently used commands with Edit accounting for 50% of the total actions. Whereas, Search commands are rarely used, accounting for only 1% of the total actions.
  > we can observe the Submit action being used as soon as Step 5, which indicates that some models submit their solution too early
- [lab] Cost: o1-preview was best but by far the most expensive; Gemini 1.5 Pro reached
  99% of its AUP at about a ninth of the cost. `7.3` ^f13
  > Gemini-1.5-Pro strikes the best balance between performance and cost on MLGym\-Bench, being the cheapest model to run (approximately 9× cheaper than OpenAI’s O1) while achieving 99% of OpenAI O1’s AUP
- [lab] Hardest were tasks needing architecture or algorithm changes (language
  modelling, RL); plain supervised tasks were handled reliably. `A.2` ^f14
  > Language Modeling and all Reinforcement Learning tasks (Meta Maze, Mountain Car Continuous and Breakout) prove the most challenging, with the highest failure rates.
  > Traditional supervised learning tasks are handled more reliably across models

## Read

- Abstract, 3 (framework, tools), 5 (setup), 7 (results, cost, failures, actions), 8
  (discussion), appendix A: fully

## Not read

- 1.1 capability levels, 2 related work, 4 task details, 6 AUP metric, appendix B
  prompts
