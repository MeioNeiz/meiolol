---
title: 'microsoft/RD-Agent: Trace of hypothesis, experiment and feedback'
url: https://github.com/microsoft/RD-Agent
kind: project
commit: 484776c211e4fbbeef03e0ec00d6bbee7362a4f4
for: [llm-experiment-agent]
looked: 2026-10-12
depth: code (rdagent/core/proposal.py, rdagent/core/knowledge_base.py, docs/project_framework_introduction.rst)
relevance: medium
grade: A/fair
description: Microsoft's open-source R&D agent framework (2024, MIT); core types record each loop as hypothesis, experiment and structured feedback in a DAG, with a pickled knowledge base
---
# microsoft/RD-Agent: Trace of hypothesis, experiment and feedback

Why: what a record of a past experiment looks like in a mature agent framework, i.e.
the shape of its experiment memory.

## Assessment

- Evidence: A. Created April 2024, ~14.9k stars, ~2k forks, 30 contributors, MIT,
  v1.0.0 September 2026, pushed October 2026; NeurIPS 2025 paper for its quant variant.
- Reasoning: fair. Core types are small and readable; design docs are thin (one page).
- Interests: Microsoft Research project.
- Weigh: trust as a schema for experiment records. Knowledge base itself is a plain
  pickled object; the smart part (cross-branch sampling) is in the paper's agent.

## Findings

- [lab] Loop framing from the docs: propose a hypothesis, design an experiment,
  implement it as code, run it, learn from the feedback, repeat.
  `docs/project_framework_introduction.rst` ^f1
  > We have established a basic method framework that continuously proposes hypotheses, verifies them, and gets feedback from the real world.
- [lab] A hypothesis record carries the hypothesis, its reason, and short fields for the
  observation, justification and knowledge behind it. `rdagent/core/proposal.py` ^f2
  > self.concise_justification: str = concise_justification
  > self.concise_knowledge: str = concise_knowledge
- [lab] Feedback per experiment: a boolean decision (better or not), a reason, a code
  change summary, and for hypotheses: observations, an evaluation of the hypothesis,
  and a proposed new hypothesis. `rdagent/core/proposal.py` ^f3
  > self.hypothesis_evaluation = hypothesis_evaluation
  > self.new_hypothesis = new_hypothesis
- [lab] Failed runs are kept as feedback with decision false and the exception as the
  reason, not dropped. `rdagent/core/proposal.py` ^f4
  > return cls(decision=False, reason=f"The experiment fails due to {e!s}", exception=e)
- [lab] Memory is a Trace: a time-ordered list of (experiment, feedback) pairs plus DAG
  parent links, so several trees can grow and the best ancestor is found by walking
  back to the last positive decision. `rdagent/core/proposal.py` ^f5
  > self.hist: list[Trace.NodeType] = (
  > self.dag_parent: list[tuple[int, ...]] = []  # List of tuples representing parent indices in the DAG structure.
  > if self.hist[i][1].decision:
- [lab] The knowledge base class is only persistence: it pickles its attributes to a
  file and loads them back. `rdagent/core/knowledge_base.py` ^f6
  > secure_pickle_dump(self.__dict__, f, serializer=pickle)

## Read

- `rdagent/core/proposal.py` (Hypothesis, feedback classes, Trace),
  `rdagent/core/knowledge_base.py`, framework docs page.

## Not read

- `rdagent/components/knowledge_management/` (graph and vector stores),
  `rdagent/scenarios/data_science/` (the MLE-bench agent): how retrieval is done.
