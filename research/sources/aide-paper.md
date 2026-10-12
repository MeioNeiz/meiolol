---
title: 'AIDE: AI-Driven Exploration in the Space of Code (Jiang et al., 2025)'
url: https://arxiv.org/abs/2502.13138
kind: paper
commit:
for: [llm-experiment-agent]
looked: 2026-10-12
depth: docs (sections 1-6, whole body; appendices skimmed)
relevance: high
grade: B/fair
description: Weco AI's paper on AIDE, an ML engineering agent that runs a hard-coded tree search over whole scripts with draft, debug and improve operators and a summarised memory
---
# AIDE: AI-Driven Exploration in the Space of Code (Jiang et al., 2025)

Why: what loop shape and operators AIDE gives an LLM for ML experimentation, and what it
claims over a linear (ReAct style) agent.

## Assessment

- Evidence: B. arXiv preprint (Feb 2025), not peer reviewed; its strongest numbers are
  third party (OpenAI MLE-bench, METR RE-Bench), re-reported here. Own benchmark is 16
  tabular Kaggle tasks, single runs, Feb 2024 submissions.
- Reasoning: fair. Clear formal loop; admits the greedy policy hits local optima and
  struggles on multi-step changes; no ablation of its own search policy.
- Interests: vendor (Weco sells a product built on AIDE).
- Weigh: trust the design description and the third-party numbers; discount "state of
  the art" framing. The comparison is tree search plus scaffold vs other scaffolds,
  so it doesn't isolate the tree from the prompts.

## Findings

- [lab] AIDE frames ML engineering as optimising code against a validation metric, with
  trial and error as a tree search over solutions. ^f1
  > AIDE frames machine learning engineering as a code optimization problem, and formulates trial-and-error as a tree search in the space of potential solutions.
- [lab] Unlike a ReAct agent that appends history to context, it stores all solutions
  in a tree and asks the LLM to improve one node at a time; a hard-coded search
  accumulates the gains. ^f2
  > AIDE organizes all historical solutions in a tree structure.
  > It then asks the LLM to propose improvements based on individual tree nodes.
- [lab] Each candidate is a whole script scored independently by a stateless objective
  (validation accuracy or loss), not a long-horizon episode. ^f3
  > rather than unrolling a single, long-horizon decision process , we can directly evaluate and compare solutions.
- [lab] Search policy is a fixed rule: draft until enough initial solutions, debug a
  buggy node within a depth limit, else improve, usually the best node. ^f4
  > Drafting if we have not yet reached the desired number of initial solutions.
  > Debugging if a buggy node remains within a certain debug depth.
  > Improving otherwise, typically targeting the best (non-buggy) solution.
- [lab] Draft writes a short plan and a single-file program; debug reads error logs and
  traces; improve makes exactly one atomic change so its effect is measurable. ^f5
  > proposes exactly one “atomic” change, such as switching optimizers or adding a regularization technique, so that its effect on performance is directly measurable.
- [lab] Memory is a summarisation operator over the tree (metrics, hyperparameters,
  debug hints), not the full log, to keep prompts small. ^f6
  > Instead of appending all historical logs, Σ(T ) selectively extracts:
- [lab] Each prompt carries a small static data preview (rows, columns, splits) from
  the workspace. ^f7
  > we store relevant metadata (e.g., number of rows, column names, or data splits) in the workspace and insert it into the coding operator’s prompt.
- [lab] On MLE-bench (OpenAI's numbers) AIDE with o1-preview got a medal in 16.9% of
  competitions, nearly four times OpenHands; other agents stopped early. ^f8
  > AIDE with o1-preview earned medals in 16.9% of competitions, nearly four times that of the follow-up agent OpenHands.
  > Other agent frameworks such as ResearchAgent from MLAB (Huang et al., 2024) and OpenHands (Wang et al., 2024) tended to terminate early or struggle with iterative refinement.
- [lab] (claim) The authors credit the gain to persistent iteration on failed solutions
  instead of abandoning them. ^f9
  > AIDE systematically addresses coding bugs and suboptimal hyperparameters rather than abandoning failed solutions.
- [lab] On METR's RE-Bench AIDE led humans within six hours but humans caught up; the
  paper blames its greedy policy for local optima, and it repeated local patches on
  multi-step tasks. ^f10
  > However, human scientists eventually caught up, as AIDE adopts a simple greedy policy that may lead to local optima on challenging R&D tasks.
  > AIDE was prone to repeating local patches instead of discovering new strategies.
- [lab] The agent makes its own validation split inside each script; the paper's own
  scoring uses a separate holdout. ^f11
  > Note that our holdout test set is also distinct from the train-validation split that AIDE itself generates as part of its internal node evaluation protocol.
- [lab] Checked, not there: no repeated evaluation of a node, no noise estimate, no
  significance test in the search; the best node is picked by its single validation
  score. ^f12
- [lab] (inferred) For meiolol the parts that transfer are the atomic-change rule, the
  bounded debug depth and the summarised memory; the free-form agent-written
  validation split does not (our eval is fixed). ^f13

## Read

- Sections 1-6 (method, evaluations, related work, conclusion).

## Not read

- Appendices (baseline configs, Weco-Kaggle task list).
