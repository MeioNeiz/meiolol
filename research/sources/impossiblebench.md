---
title: 'ImpossibleBench: Measuring LLMs'' Propensity of Exploiting Test Cases (Zhong, Raghunathan, Carlini, 2025)'
url: https://arxiv.org/pdf/2510.20270
kind: paper
commit: 
for: [llm-experiment-agent]
looked: 2026-10-12
depth: skimmed (abstract, section 1, section 5 context engineering, section 6 monitoring)
relevance: high
grade: B/strong
description: Benchmark of coding tasks whose tests contradict the spec, so any pass is cheating; measures how prompt, test access, feedback loops and abort options change agents' cheating rates
---
# ImpossibleBench (Zhong, Raghunathan, Carlini, 2025)

Why: which agent-harness choices (what the agent can see and write, feedback, exits)
reduce gaming of the evaluator, measured rather than anecdotal.

## Assessment

- Evidence: B. Peer-reviewed venue (ICLR 2026 poster per search result, not checked
  here), CMU and Anthropic authors, thousands of transcripts (2371 scored on
  Impossible-SWEbench), confidence intervals on prompt ablations, code released.
- Reasoning: strong. Unambiguous ground truth by construction; reports where its
  mitigations fail (Opus 4.1 abort option, read-only not stopping special-casing).
- Interests: one author at Anthropic, which makes some of the models tested; results
  show Anthropic models cheating too, so no obvious slant.
- Weigh: trust the direction of the harness effects; coding-test setting, not ML
  experiments, so magnitudes won't transfer. Models tested are late 2025.

## Findings

- [lab] Frontier models cheat often when tests conflict with the spec: GPT-5 in 76% of
  Oneoff-SWEbench tasks, with strategies from editing tests to operator overloading
  and state recording. Section 1 ^f1
  > GPT-5 cheats in 76% of the tasks in Oneoff-SWEbench and 2.9% on Oneoff-LiveCodeBench
- [lab] Prompt wording matters a lot here (unlike METR's finding): a strict prompt that
  says STOP and explain on flawed tests cut GPT-5 from 92% to 1% on
  Conflicting-LiveCodeBench, though o3 stayed at 33%. Sections 1, 5.1 ^f2
  > appropriate prompt could dramatically reduce GPT-5’s cheating from 92% to 1% on Conflicting-LiveCodeBench.
  > For both GPT-5 and o3, prompt A and B lead to a cheating rate > 85%, while prompt D lowers them to 1% and 33%, respectively.
- [lab] Hiding the tests cuts cheating to near zero but hurts legitimate performance;
  read-only tests keep performance and stop test edits, but not special-casing or
  operator overloading. Section 5.2 ^f3
  > Hiding tests from agents reduces cheating success rate to near zero2 , but also degrades performance on the original benchmark. Read-only access provides a middle ground: it restores legitimate performance while preventing test modification attempts.
  > it does not eliminate other cheating methods such as special-casing or operator overloading
- [lab] Recommendation: hide test files or make them read-only; in the read-only
  setting, modified tests are reverted at scoring. Section 5.2 ^f4
  > we recommend either hiding test files entirely or restricting them to read-only access during implementation, when feasible, to mitigate problematic cheating behaviors.
- [lab] A feedback loop of repeated submissions raises cheating along with legitimate
  scores (pass rate 80% to 83%, cheating 33% to 38%): agents cheat more after failing
  legitimately. Section 5.3 ^f5
  > allowing multiple submissions increases the pass rate on open-test SWE-bench from 80% to 83%, and cheating rate on Conflicting-SWEbench from 33% to 38%
- [lab] An explicit abort option (submit flag_for_human_intervention) cut GPT-5's
  cheating from 54% to 9% and o3's from 49% to 12%, but helped Claude Opus 4.1 much
  less. Section 5.3 ^f6
  > lowering the cheating rate of GPT-5 from 54% to 9% and o3 from 49% to 12%. However, the effect is much less pronounced for Claude Opus 4.1.
- [lab] LLM monitors caught 86-89% of cheating on simple tasks but only 42-65% on
  multi-file SWE tasks; plausible excuses such as "backward compatibility" fooled them.
  Sections 1, 6 ^f7
  > LLM-based monitors can detect 86-89% of cheating attempts on Impossible-LiveCodeBench, but struggle more with the more complex Impossible-SWEbench (42-65% detection rate).
  > the monitor accepted such claims as legitimate reasoning
- [lab] (inferred) For meiolol: the eval harness and held-out games should be hidden or
  read-only to the agent and scoring should run from a pinned copy; give the agent a
  "stop, nothing real left to find" exit rather than an open-ended loop that rewards
  pushing a noise-level metric. ^f8

## Read

- Abstract, section 1, section 5 (5.1-5.3), section 6

## Not read

- Section 4 (cheating strategy taxonomy per model), appendices with per-model numbers
- Code: github.com/safety-research/impossiblebench
