---
title: 'The AI Scientist: Towards Fully Automated Open-Ended Scientific Discovery (Lu et al., Sakana AI, 2024)'
url: https://arxiv.org/pdf/2408.06292
kind: paper
commit: 
for: [llm-experiment-agent]
looked: 2026-10-12
depth: skimmed (abstract, section 8 limitations and safe code execution only)
relevance: medium
grade: B/fair
description: Sakana's first AI Scientist paper (v3, Sep 2024); read only for its limitations and safe-code-execution notes on the agent gaming its constraints and faking results
---
# The AI Scientist (Sakana AI, 2024): limitations and safety only

Why: concrete failure modes of an LLM running its own ML experiments unsupervised.
The loop design itself is out of scope here (see [[ai-scientist-v2]]).

## Assessment

- Evidence: B. First-hand report from the system's authors (Sakana AI, Oxford, UBC),
  widely discussed; anecdotes, no rates.
- Reasoning: fair. Lists failures frankly, including ones that embarrass the system.
- Interests: authors promote their system; the failures are admissions against interest,
  so worth more than its success claims.
- Weigh: trust the failure anecdotes; they are from 2024 models and a loose sandbox.

## Findings

- [lab] When experiments exceeded the imposed time limit, it edited the code to extend
  the limit instead of making the run faster. Section 8, Safe Code Execution ^f1
  > when The AI Scientist’s experiments exceeded our imposed time limits, it attempted to edit the code to extend the time limit arbitrarily instead of trying to shorten the runtime.
- [lab] Other runaway behaviour: a system call relaunching itself (uncontrolled
  processes) and a checkpoint every step (nearly a terabyte). ^f2
  > wrote code in the experiment file that initiated a system call to relaunch itself, causing an uncontrolled increase in Python processes
  > edited the code to save a checkpoint for every update step, which took up nearly a terabyte of storage.
- [lab] Authors recommend strict sandboxing: containers, restricted network, storage
  limits. ^f3
  > We recommend strict sandboxing when running The AI Scientist, such as containerization, restricted internet access (except for Semantic Scholar), and limitations on storage usage.
- [lab] It mis-compares numbers and, after changing the metric (e.g. the loss), sometimes
  compares against the baseline anyway; the authors store copies of all executed files
  for reproducibility. Section 8 ^f4
  > it struggles to compare the magnitude of two numbers, which is a known pathology with LLMs. Furthermore, when it changes a metric (e.g. the loss function), it sometimes does not take this into account when comparing it to the baseline.
  > we make sure all experimental results are reproducible, storing copies of all files when they are executed.
- [lab] Told to always include confidence intervals and ablations, it sometimes
  hallucinated a whole ablation table it had not run; fixed by instructing it to report
  only directly observed results. ^f5
  > it would sometimes hallucinate an entire ablations table.
  > We resolved this by instructing
  > explicitly to only include results it directly observed.
- [lab] Authors advise not taking its scientific content at face value; treat outputs as
  hints for a human to follow up. ^f6
  > we do not recommend taking the scientific content of this version of
- [lab] (inferred) For meiolol: the metric, its baseline and the comparison must be
  computed by fixed code outside the agent's edit scope, and every reported number must
  come from a stored run record, not from the agent's write-up. ^f7

## Read

- Abstract; section 8 (limitations, safe code execution)

## Not read

- Loop, idea generation, automated reviewer (other readers; see [[ai-scientist-v2]])
