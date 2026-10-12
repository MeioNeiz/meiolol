---
title: 'MLE-bench: Evaluating Machine Learning Agents on Machine Learning Engineering'
url: https://arxiv.org/html/2410.07095
kind: paper
commit:
for: [llm-experiment-agent]
looked: 2026-10-12
depth: docs (sections 2.3, 3, 6, appendix A.3-A.6)
relevance: high
grade: A/fair
description: OpenAI benchmark of 75 Kaggle competitions for ML agents; compares AIDE, MLAB and OpenHands scaffolds, attempts (pass@k), hardware and time budgets
---
# MLE-bench: Evaluating Machine Learning Agents on Machine Learning Engineering

Why: which scaffolds, tools and budgets help an LLM agent doing ML engineering, and how
such agents fail.

## Assessment

- Evidence: A. OpenAI, October 2024 (ICLR 2025), 75 competitions, 3 seeds per setup
  (16 and 36 for the two main AIDE runs), mean and standard error reported; the
  standard reference benchmark for ML-engineering agents.
- Reasoning: fair. Results are measured; the failure analysis is qualitative (from
  reading transcripts), with no counts. Models are 2024 ones (o1-preview, GPT-4o).
- Interests: OpenAI's own models score best; scaffolds are third-party and lightly
  tuned by the authors.
- Weigh: trust the scaffold comparison and the pass@k and time curves as direction,
  not exact sizes for current models. Kaggle tasks have a clean metric and big data,
  unlike our small, noisy one.

## Findings

- [lab] With the same model (GPT-4o), the purpose-built AIDE scaffold won far more
  medals than the general-purpose MLAB and OpenHands, at a similar number of valid
  submissions. `3.1` ^f1
  > GPT-4o (AIDE) achieves more medals on average than both MLAB and OpenHands (8.7% vs. 0.8% and 4.4% respectively), despite making a similar number of valid submissions.
- [lab] The model mattered as much as the scaffold: o1-preview with AIDE won a medal
  in 16.9% of competitions, almost twice the next model. `3.1` ^f2
  > We find that o1-preview significantly outperforms all other models, achieving a medal on 16.9% of competitions - almost twice the number of medals on average as the next best model
- [lab] Agents often failed to make valid submissions and skipped the validation tool
  even when prompted to use it. `3.1 Discussion` ^f3
  > All agents often failed to create valid submissions, despite having access to the validation server.
  > they did not always use the validation server, despite their prompts encouraging them to do so.
- [lab] General agents quit early; AIDE kept going because the scaffold re-prompts
  for improvement until time or 500 nodes run out. `3.1 Discussion` ^f4
  > We found that MLAB and OpenHands tend to end their runs early, sometimes within the first few minutes, despite being told to optimize their scores as much as possible for the full 24-hour duration.
  > the AIDE scaffold repeatedly prompts models to improve their score until the full 24 hours is up, or when it has generated 500 nodes
- [lab] More tools means more ways to fail: MLAB filled its context by inspecting
  files thousands of lines long. `3.1 Discussion` ^f5
  > MLAB and OpenHands are given a variety of tools to solve open-ended tasks, though this flexibility also increases the risk surface area for failure.
  > MLAB often attempted to inspect files that were thousands of lines long, which ended up filling its context window.
- [lab] Agents ignored compute and time limits: they overloaded disk or RAM, got
  killed, and rarely considered how long their code would run. `3.1 Discussion` ^f6
  > All three agents failed to effectively factor in compute and time limitations to their strategies.
  > agents rarely verbalized any consideration of how long their produced code would run for.
- [lab] More independent attempts help a lot: pass@6 roughly doubles pass@1, and
  GPT-4o at pass@6 matched o1-preview at pass@1. `3.2` ^f7
  > GPT-4o (AIDE) with pass@6 achieves a comparable score (17.0%) to o1-preview (AIDE) with pass@1 (16.9%). Notably, both agents’ pass@6 scores are roughly double their pass@1 scores.
- [lab] More hardware did not help: CPU-only, one GPU and two GPUs scored similarly,
  and the agent never tried to use the second GPU. `3.3` ^f8
  > Surprisingly, we find that GPT-4o (AIDE) performs similarly in all experiments.
  > didn’t identify any attempts from GPT-4o AIDE to use the second GPU.
- [lab] More time has diminishing returns: most medals come in the first couple of
  hours of a 100-hour run, and the score can drop because AIDE's best-attempt
  selection is imperfect. `3.4` ^f9
  > GPT-4o (AIDE) achieves a significant number of medals in the first couple hours of execution, then slowly accumulates more medals over the course of the run.
  > Sometimes the number of medals GPT-4o (AIDE) achieves actually decreases, which is due to the imperfect method AIDE uses to select its “best" attempt.
- [lab] Scaffold fixes that helped robustness: tell the agent its total time, the
  per-command timeout and hardware, and put time and steps remaining in every turn.
  `A.6` ^f10
  > For all scaffolds we ensure that the agent is prompted with the total time available to complete the task, the timeout any code execution has before being forcibly terminated (if any), and the hardware available.
  > We additionally insert information about the time and steps remaining into the end-of-turn prompt for all scaffolds.
- [lab] Further fixes: truncate long observations, give full error messages, discourage
  the "final answer" tool until all avenues are tried. `A.6.3` ^f11
  > Truncate observations with "…TRUNCATED" when the “List Files” tool exceeds 10,000 characters.
  > Include full error messages in all EnvException exceptions so that the agent can debug more effectively.
  > we modify the description of the “Final Answer” tool to make it clear that the agent should not use this tool unless it has exhausted all avenues for improving their solution.
- [lab] Guards: an LLM reads agent logs for rule-breaking (writing predictions by
  hand, calling other LLMs), plus a code-plagiarism check; the log checker was
  over-cautious and every flag was a false positive. `2.3.1`, `A.3` ^f12
  > the tool checks if the agent has broken the rules by manually writing the submission file without using a model, calling another external LLM API for assistance, or attempting to access unauthorized resources.
  > We found gpt-4o-mini to be overly cautious, flagging valid behaviors as violations even when they were not.
- [lab] Cost: a 24-hour attempt per competition is 1800 GPU hours per seed, and
  o1-preview with AIDE used 127.5M input tokens per seed of 75 tasks. `6` ^f13
  > o1-preview with AIDE used 127.5M input tokens and 15.0M output tokens on average for one seed of 75 competitions.

## Read

- Abstract, 2.3 (setup, rules), 3 (all experiments), 6 (limitations), A.3-A.6
  (log analysis, setup, scaffold changes): fully

## Not read

- 4 (contamination), A.7-A.9 (dataset list, per-category results): not about tools
- Table 2, 3 and 7 contents (HTML tables not in the snapshot text)
