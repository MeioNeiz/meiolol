---
title: 'WecoAI/aideml: AIDE reference implementation'
url: https://github.com/WecoAI/aideml
kind: project
commit: 74d810f79db6e9e2d37e4465a6e84075333fe310
origin: aide-paper
for: [llm-experiment-agent]
looked: 2026-10-12
depth: code (aide/agent.py, aide/journal.py, aide/utils/config.yaml, README.md)
relevance: high
grade: B/fair
description: open-source AIDE agent; how its search policy, operators, LLM reviewer and journal memory are actually coded and configured
---
# WecoAI/aideml: AIDE reference implementation

Why: what the AIDE loop gives the LLM in practice (actions, memory, defaults), beyond
the paper's description.

## Assessment

- Evidence: B. Created April 2024, ~1.6k stars, 236 forks, 17 contributors, MIT,
  release v0.2.2 (Nov 2025), pushed today; has a tests/ folder. The scaffold OpenAI
  used in MLE-bench.
- Reasoning: fair. Code is small and readable; config documents each knob.
- Interests: vendor (README pushes the Weco product).
- Weigh: trust as the reference for what AIDE does; the defaults (20 steps, 1 h
  timeout) are tuned for Kaggle tasks, not ours.

## Findings

- [lab] The search policy in code: draft until `num_drafts`, then with probability
  `debug_prob` debug a random buggy leaf under `max_debug_depth`, else improve the
  single best node (greedy). `aide/agent.py` ^f1
  > if random.random() < search_cfg.debug_prob:
  > greedy_node = self.journal.get_best_node()
- [lab] Defaults: 20 steps, 5 drafts, debug probability 0.5, max debug depth 3, a
  3600 s execution timeout, 5-fold CV suggested. `aide/utils/config.yaml` ^f2
  > debug_prob: 0.5
  > max_debug_depth: 3
  > k_fold_validation: 5
- [lab] The LLM has no tools: each step it returns a 3-5 sentence plan and one full
  code block; the harness runs it. `aide/agent.py` ^f3
  > Your response should be a brief outline/sketch of your proposed solution in natural language (3-5 sentences), followed by a single markdown code block
- [lab] Improve prompt demands one atomic, testable change. `aide/agent.py` ^f4
  > This improvement should be atomic so that we can experimentally evaluate the effect of the proposed change.
- [lab] A second, cheaper LLM reads the run output and returns a structured review: a
  bug flag, a 2-3 sentence summary, the metric and its direction. `aide/agent.py` ^f5
  > "description": "if there is a bug, propose a fix. Otherwise, write a short summary (2-3 sentences) describing the empirical findings.",
  > model: gpt-4.1-mini
- [lab] The metric is read by that LLM from stdout, not parsed by the harness; a NaN
  or missing metric marks the node buggy. `aide/agent.py` ^f6
  > "description": "If the code ran successfully, report the value of the validation metric. Otherwise, leave it null.",
  > NaN passes isinstance(..., float), so a diverged run that reports a NaN
- [lab] Memory is the plan, review summary and metric of every good node, put in each
  draft and improve prompt; buggy nodes are left out. `aide/journal.py` ^f7
  > for n in self.good_nodes:
  > summary_part += f"Validation Metric: {n.metric.value}\n"
- [lab] Each script must print a hold-out validation metric and finish within the
  timeout; the agent picks the split. `aide/agent.py` ^f8
  > The code should **implement the proposed solution** and **print the value of the evaluation metric computed on a hold-out validation set**.
- [lab] Tools beyond the loop: HTML tree visualiser and a report generated from the
  journal. `README.md`, `aide/utils/config.yaml` ^f9
  > inspect the full solution tree and code attached to each node.
  > generate_report: True
- [lab] Checked, not there: no re-runs or seeds per node, no confidence intervals; best
  node is `max` over single scores. `aide/journal.py` ^f10
  > return max(nodes, key=lambda n: self._metric_rank(n.metric))

## Read

- `aide/agent.py` whole; `aide/journal.py` summary and best-node; config; README top.

## Not read

- `aide/interpreter.py` (sandboxed execution), `journal2report.py`, tests, webui.
