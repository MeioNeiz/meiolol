---
title: AI Agents That Matter
url: https://arxiv.org/html/2407.01502
kind: paper
commit:
for: [agent-ml-practice, llm-experiment-agent]
looked: 2026-10-13
depth: docs (sections 1-3, 5, 6)
relevance: medium
grade: A/strong
description: Kapoor, Stroebl, Siegel, Nadgir, Narayanan (Princeton, 2024): agent evaluations must report cost with accuracy, compare against simple retry baselines, keep proper holdouts, and repeat runs
---
# AI Agents That Matter

Why: what a careful evaluation of agents demands (cost control, baselines, holdouts,
repeats), to apply to how meiolol judges its own lab agent and its experiments.

## Assessment

- Evidence: A. Widely cited Princeton paper (Narayanan's group), re-ran published
  agents five times each with costs; findings on HumanEval, HotPotQA, WebArena.
- Reasoning: strong. Shows the baselines, admits HumanEval may be too easy for "System
  2" methods to pay, separates benchmark and agent developers' duties.
- Interests: none (academic critique).
- Weigh: the HumanEval numbers are old (2024 models); the principles carry.

## Findings

- [lab] Simple baselines (retry up to five times, retry with rising temperature,
  escalate from cheap to dear models) matched or beat published agent architectures on
  HumanEval at far lower cost. `§2.3` ^f1
  > “State-of-the-art” agent architectures for HumanEval do not outperform simple baselines.
- [lab] Cost differs by almost 100x at similar accuracy; LATS cost over 50 times the
  warming baseline. `§2.3` ^f2
  > For substantially similar accuracy, the cost can differ by almost two orders of magnitude.
- [lab] Claimed gains from planning, reflection and debugging were not shown against
  simple baselines, so their worth is open. `§2.3` ^f3
  > it has led to widespread beliefs in the community that complex ideas like planning, reflection, and debugging are responsible for accuracy gains.
- [lab] Accuracy alone cannot show progress, because retrying raises it without any
  scientific idea; compare at equal cost. `§2.3` ^f4
  > Accuracy alone cannot identify progress because it can be improved by scientifically meaningless methods such as retrying.
- [lab] Report cost and accuracy as a Pareto frontier; joint optimisation cut variable
  cost 53% (GPT-3.5) and 41% (Llama-3-70B) at similar accuracy on HotPotQA. `§3.2` ^f5
  > for GPT-3.5, joint optimization leads to 53% lower variable cost with similar accuracy compared to both default DSPy implementations.
- [lab] Holdouts: overfitting is a worse risk than contamination for small agent
  benchmarks, since knowledge of test items can be programmed in; keep the test set
  secret. `§5` ^f6
  > This is a much more serious problem than LLM training data contamination, as knowledge of test samples can be directly programmed into the agent as opposed to merely being exposed to them during training.
- [lab] Of 17 benchmarks surveyed, most lacked a holdout at the right level of
  generality; 7 had none and no plan for one. `§5` ^f7
  > the majority of benchmarks do not include an appropriate held-out set, including 7 that have no hold-out and no indication that a holdout set will be added
- [lab] Agent evals are rarely repeated because they are costly; many published scores
  sat above the maximum of the authors' five reproduction runs and baselines below the
  minimum. `§6` ^f8
  > We found that many reported accuracy scores were above the maximum of five runs that we performed in our reproduction attempts, and the reported baselines were in some cases lower than the minimum of five runs we performed.
- [lab] Evaluation bugs: two leading agents marked some failed tasks as passed and
  silently dropped tasks from the benchmark. `§6` ^f9
  > both LATS \[[65]\] and STeP \[[47]\] marked some incorrectly completed tasks as correct.
- [lab] Task order can matter when tasks share an environment (rate limits made
  back-to-back Reddit tasks fail), breaking the independence assumption. `§6` ^f10
  > This assumption fails for WebArena \[[66]\].
- [lab] (inferred) For meiolol's lab harness: judge a lab agent or a model change at
  equal cost (GPU minutes, tokens) against a dumb baseline (rerun with another seed,
  plain sweep); log cost per run beside the metric; keep a sealed test only the human
  scores; count dropped or crashed runs rather than averaging over survivors. ^f11

## Read

- Abstract, sections 2, 3, 5, 6, 7.

## Not read

- Section 4 (model vs downstream developers, NovelQA) and appendices.
