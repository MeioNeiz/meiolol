---
title: 'R&D-Agent: research and development phases for ML engineering agents (arXiv 2505.14738)'
url: https://arxiv.org/pdf/2505.14738
kind: paper
commit:
for: [llm-experiment-agent]
looked: 2026-10-12
depth: docs (sections 1-4, appendix C.3, D.3, E.4)
relevance: high
grade: B/fair
description: Microsoft's MLE agent framework paper; splits a research phase (planning, path structure, memory, reasoning) from a development phase (coding, evaluation), with one-at-a-time ablations on MLE-bench
---
# R&D-Agent: research and development phases for ML engineering agents (arXiv 2505.14738)

Why: the research vs development split, how past experiments are remembered across
branches, and which loop components matter by ablation.

## Assessment

- Evidence: B. Microsoft Research; repo has ~14.9k stars, 30 contributors. Main result
  3 seeds with SEM; ablations are single runs on a 40-task subset (stated), so each
  ablation number is one noisy draw.
- Reasoning: fair. Clear decomposition and ablations per component, admits ablations
  are single runs; the "human-expert-inspired" choices are justified by analogy more
  than measurement.
- Interests: authors' own framework compared against baselines they reran.
- Weigh: trust the component list and the aggregated evaluation, sampled-data debug and
  fixed split ideas. Treat ablation sizes (9% to 28%) as rough: single runs.

## Findings

- [lab] Two phases: a Research agent proposes ideas (planning, exploration path,
  memory context, reasoning pipeline); a Development agent turns them into running
  code and gets scored (coding workflow, evaluation strategy). `section 1, 3.1` ^f1
  > R&D-Agent separates: (i) a Research phase focused on idea generation and search
  > The research phase aims to discover and refine promising ideas before committing to costly implementation.
- [lab] Frames the agent's job: tune only on a development split against a proxy
  metric; the test split is never seen. `section 2` ^f2
  > This fundamental separation means the agent never has access to the final evaluation metric during its development process.
- [lab] Dynamic planning: small compute budget early (no ensembles, no CV), more later;
  early ideas favour novelty, late ones refine proven solutions. `3.3 MD-Planning` ^f3
  > In the early stage (e.g., the first hour), the agent is given a limited computational budget, which discourages the use of heavy techniques such as ensembles or cross-validation.
  > early stages encourage novelty, while later stages focus on refining high-performing solutions with proven techniques.
- [lab] Exploration: maximise diversity in the first layer (distinct directions), then
  greedy within each branch with pruning, merging branches at the end. Reason: first
  implementations fix the path. `3.3 MD-Exploration Path Structuring` ^f4
  > initial implementations have disproportionate impact on exploration diversity, as subsequent steps are inherently path-dependent.
  > we maximize diversity in the first layer to establish distinct research directions, then greedily exploit the best solution within each branch while pruning sub-optimal paths.
- [lab] Reasoning: identify the main problem, hypothesise why a method fixes it, then
  generate several ideas and let an LLM pick one ("virtual evaluation") because running
  is dearer than proposing. `3.3 MD-Scientific Reasoning Pipeline` ^f5
  > Since verifying ideas is more costly than generating them, we introduce a virtual evaluation strategy
- [lab] Memory across branches: each branch's context gets the best ideas from all
  branches plus a sample favouring similar, higher-scoring and recent ideas; an LLM
  then selects, modifies or generates. `3.3 MD-Memory Context, D.3` ^f6
  > we augment each branch’s context with two sources: the best ideas across all branches and a probabilistically sampled subset from others.
  > The sampling kernel favors ideas that are topically similar and have higher scores, with more recent ideas weighted higher.
- [lab] Analysis prompt per experiment: compare with the best so far, analyse the code
  diff, and say whether results support or refute the hypothesis; reuse past outcomes.
  `appendix E.4 Memory Context` ^f7
  > Hypothesis Validation: Whether experimental results support or refute the hypothesis
  > Code Change Analysis: Analyze implementation differences via diff
- [lab] Coding workflow: debug on a small sample of the data until the code runs and
  makes sense; only then run on the full data. `3.3 MD-Coding Workflow` ^f8
  > Only validated solutions proceed to full-scale evaluation.
- [lab] [method] Evaluation: fixed train, validation, test splits made at the start,
  and the top solutions from each branch rescored on the same validation set before
  choosing. `3.3 MD-Evaluation Strategy` ^f9
  > we enforce standardized data splitting: preparing fixed train-validation-test splits at the beginning of agent runs, with test data remaining entirely inaccessible for final grading.
  > collects top solutions from different exploration branches and evaluates them using consistent metrics on the same validation set.
- [lab] Ablation (single runs, 40 tasks): chain instead of adaptive tree cut any-medal
  from 35.1% to 25.3%; one-step reasoning to 26.7%, improve rate 41% to 23%; simpler
  memory only to 32.0%. `4.3.1, table 3` ^f10
  > Any Medal Rate drops to 25.3% and average loops fall dramatically (45.9→19.4)
  > showing the smallest degradation to 32.0% Any Medal Rate.
- [lab] Development ablation: full-data debugging dropped to 24.0%; without aggregated
  evaluation results matched until hour 2, then fell to 30.7%. `4.3.2` ^f11
  > Performance drops immediately to 24.0% Any Medal Rate and remains persistently degraded.
- [lab] Only about 41% of R&D loops improve on the best so far, about 46 loops per task
  in 12 hours. `table 3` ^f12
  > Improve Rate: percentage of R&D loops yielding performance gains
- [lab] Final pick by validation reaches 93% of an oracle that picks by test score.
  `4.3.2` ^f13
  > Achieving 93% of perfect selection demonstrates effective solution identification without test set access.
- [lab] Cost: 12 hours on one V100 per task, against 24 hours and up to 8 GPUs for
  other agents; LLM spend in dollars not given in sections read. `appendix C.3` ^f14
  > R&D-Agent achieves state-of-the-art performance using only a single NVIDIA V100 GPU within 12 hours

## Read

- Sections 1-4, appendix C.3 (efficiency), D.3 (memory context design), E.4 (memory
  prompts).

## Not read

- Appendix C.1-C.2 (backend LLMs, external knowledge), E (other prompts), case study,
  code comparison with ML-Master.
