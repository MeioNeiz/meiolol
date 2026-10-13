---
title: 'Agent Laboratory: Using LLM Agents as Research Assistants (Schmidgall et al., 2025)'
url: https://arxiv.org/html/2501.04227
kind: paper
commit: 
for: [agent-ml-practice]
looked: 2026-10-13
depth: listed (abstract, 3.2, 4.1-4.2, 5.1-5.2)
relevance: medium
grade: C/fair
description: AMD/JHU research-assistant agent (literature, plan, mle-solver experiments, report) with optional human co-pilot; its own limitations list (0% accuracy left uncorrected, exit() calls, hallucinated setups) and human vs LLM reviewer gap
---
# Agent Laboratory (Schmidgall et al., 2025)

Why: what failed in a widely used ML research agent, by its authors' own account, and
what human-in-the-loop review changed.

## Assessment

- Evidence: C. System paper by its builders: 15 autonomous papers rated by 10 PhD
  students, a small co-pilot study (handful of researchers), failure modes listed
  without counts. Audited independently by [[luo-hidden-pitfalls]].
- Reasoning: fair. Honest limitations section; claims of SOTA code and "human
  involvement significantly improves quality" rest on small samples.
- Interests: authors of the system.
- Weigh: trust the qualitative failure list and the LLM-reviewer inflation; discount
  quality-score differences of a few tenths.

## Findings

- [lab] mle-solver keeps the best programs by an LLM reward model that scores plan,
  code and observed output 0 to 1, not by a fixed metric (the channel through which
  test scores reach selection, per Luo et al.). 3.2 ^f1
  > The reward model, invoked as an LM, scores the program on a scale from 0 to 1 considering the outlined research plan, the produced code, and the observed output
- [lab] Silent nonsense survives: experiments sometimes got 0% accuracy for every method
  and the agent did not fix it before running out of steps. 5.2 ^f2
  > Experiments run by mle-solver sometimes obtain 0% accuracy for all tested methods which is not corrected by the agent by the time mle-solver runs out of solving steps.
- [lab] The agent often called exit(), killing the whole process; removed by hand. It
  also ran host system commands via subprocess. 5.2 ^f3
  > mle-solver often generated the python exit() command, which terminated the entire process. This had to be detected and removed manually.
- [lab] Printed output from data preparation or results can exhaust the model's token
  limit. 5.2 ^f4
  > Printed output from the data preparation or experimental results can lead to the LLMs reaching their token limit.
- [lab] Hallucinated experimental details (learning rate, batch size, 50 epochs, early
  stopping) for runs that did not happen, mostly with weaker models such as gpt-4o;
  "uncommon" but no count. 5.1 ^f5
  > there were hallucinations regarding experimental results that did not occur
- [lab] LLM reviewers inflate: automated reviewers gave 6.1/10 on average, humans 3.8/10
  for the same papers. 4.1.1 ^f6
  > While the automated reviewers gave an average overall above average NeurIPS paper score of 6.1/10, human reviewers provided a much lower average of 3.8/10 (-2.3 points).
- [lab] Human-rated experiment quality was low: 2.6/5 (gpt-4o), 3.2/5 (o1-mini),
  2.9/5 (o1-preview), 15 papers. 4.1 ^f7
  > gpt-4o consistently achieved lower scores, with an average experimental quality rating of 2.6/5
- [lab] Human co-pilot raised external overall scores (+0.58) mostly through
  presentation, not experimental results; co-pilots rated experiment quality 2.38/5 and
  found it hard to make the agents carry out their exact plan. 4.2 ^f8
  > much of the focus of human involvement going toward making the paper more presentable (presentation and clarity) while there was less emphasis on improving experimental results
  > the reduction in scores is due to difficulty guiding the agents to execute their exact vision for the project.
- [lab] Researchers asked for better inspection of intermediate results. 4.2.1 ^f9
  > better inspection of intermediate results
- [lab] Checked, not there: no audit of leakage, test-set use or baselines in the paper
  itself; those come from [[luo-hidden-pitfalls]]. ^f10
- [lab] (inferred) For meiolol: the harness should reject degenerate results (every
  arm at chance or 0%, constant predictions) before the agent reasons about them, cap
  printed output, and treat any LLM self-rating as uninformative. ^f11

## Read

- Abstract, 3.2 (mle-solver), 4.1, 4.1.1, 4.2, 5.1, 5.2.

## Not read

- 4.3-4.4 runtime, cost, MLE-Bench subset (not about experiment failures); prompts.
