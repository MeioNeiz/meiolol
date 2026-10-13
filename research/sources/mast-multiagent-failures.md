---
title: Why Do Multi-Agent LLM Systems Fail? (MAST, Cemri et al. 2025)
url: https://arxiv.org/html/2503.13657
kind: paper
commit: 
for: [agent-ml-practice]
looked: 2026-10-13
depth: docs (abstract, sections 4-5, appendix A.3)
relevance: medium
grade: B/fair
description: Berkeley taxonomy of 14 failure modes from 1,642 traces of 7 multi-agent LLM frameworks
---
# Why Do Multi-Agent LLM Systems Fail? (MAST, Cemri et al. 2025)

Why: our modelling programme is ~15 Claude sessions with a coordinator; which
coordination and verification failures should the setup design against?

## Assessment

- Evidence: B. 1,642 annotated traces, 7 frameworks, taxonomy from 150 traces with
  inter-annotator kappa 0.88; tasks are mostly programming and maths, not ML experiments
- Reasoning: fair. Clear definitions and two small intervention studies; prevalences
  depend on which systems and tasks were sampled
- Interests: none known (academic)
- Weigh: trust the categories and the "verifiers check only superficially" finding;
  the percentages describe their sample, not ours

## Findings

- [lab] 14 failure modes in 3 categories: system design, inter-agent misalignment,
  task verification. `abstract` ^f1
  > This process identifies 14 unique modes, clustered into 3 categories: (i) system design issues, (ii) inter-agent misalignment, and (iii) task verification.
- [lab] Commonest single modes: step repetition 15.7%, reasoning-action mismatch 13.2%,
  not recognising completion 12.4%, disobeying the task spec 11.8%. `4` ^f2
  > failing to follow task requirements (FM-1.1, 11.8%) or agent roles (FM-1.2, 1.5%), step repetitions (FM-1.3, 15.7%), context loss (FM-1.4, 2.80%), or not recognizing task completion (FM-1.5, 12.4%)
- [lab] Verification failures: premature termination 6.2%, no or incomplete
  verification 8.2%, incorrect verification 9.1%. `4` ^f3
  > premature termination (FM-3.1, 6.20%), no or incomplete verification (FM-3.2, 8.20%), or incorrect verification (FM-3.3, 9.10%)
- [lab] Explicit verifiers help, but most only check the surface (does it compile);
  they argue for multi-level checks of low-level correctness and the high-level goal.
  `4` ^f4
  > many existing verifiers perform only superficial checks, despite being prompted to perform thorough verification, such as checking if the code compiles or if there are leftover TODO comments
- [lab] Adding a high-level objective verification step to ChatDev raised task success
  15.6%; clearer role specifications alone 9.4%, same model and prompt. `4` ^f5
  > adding a high-level task objective verification step to ChatDev yields a +15.6% improvement in task success on ProgramDev
  > improving agent role specifications alone yields a +9.4% success rate increase for ChatDev
- [lab] Coordination failures (wrong assumptions instead of asking 6.8%, derailment
  7.4%, withholding information 0.85%) happen even with shared message formats; the
  authors put them down to agents not modelling what others need to know. `4` ^f6
  > the collapse of ’theory of mind’ [[48](https://arxiv.org/html/2503.13657#bib.bib48)], where agents fail to accurately model other agents’ informational needs
- [lab] (inferred) For us: structured hand-offs (what a result is compared against,
  which build and snapshot) address withholding and wrong assumptions better than prose
  messages between sessions. ^f7

## Read

- abstract, section 4, 5.1-5.3, appendix A.3

## Not read

- Appendix G strategies table, H intervention details, N examples
