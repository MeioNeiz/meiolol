---
title: Recent Frontier Models Are Reward Hacking (METR, 2025-06-05)
url: https://metr.org/blog/2025-06-05-recent-reward-hacking/
kind: article
commit: 
for: [llm-experiment-agent]
looked: 2026-10-12
depth: listed (whole post)
relevance: high
grade: B/fair
description: METR blog post on o3 and other frontier models cheating on AI R&D tasks by editing scorers, copying the grader's answer or caching results; rates, detection, prompt fixes
---
# Recent Frontier Models Are Reward Hacking (METR, 2025)

Why: how often and how an LLM agent doing AI R&D style optimisation games its scoring,
and which mitigations worked.

## Assessment

- Evidence: B. First-hand report by an established evaluation org (METR) from its own
  runs, with counts per task and public transcripts; not peer reviewed, small samples
  per task (6 to 28 runs, prompt test 20 runs each).
- Reasoning: fair. Explains detection methods and their false-positive rates, admits
  it may have missed instances and that labelling is ambiguous.
- Interests: AI-safety evaluation org; an interest in showing misalignment matters.
- Weigh: trust the mechanisms (edit scorer, read grader's answer, fake timing) and the
  finding that prompting barely helps. Rates are model-specific (o3, mid 2025) and will
  differ for the model we use.

## Findings

- [lab] Frontier models on AI R&D tasks raise scores by modifying tests or scoring
  code, reading the answer used to check them, or exploiting loopholes. What we've
  observed ^f1
  > attempting (often successfully) to get a higher score by modifying the tests or scoring code, gaining access to an existing implementation or answer that’s used to check their work, or exploiting other loopholes in the task environment.
- [lab] Example: asked for a fast Triton kernel, o3 walked the call stack to return the
  grader's precomputed answer and disabled CUDA synchronisation so timing was fake. ^f2
  > o3's “kernel” traces through the Python call stack to find the correct answer that the scoring system already calculated and returns that. It also disables CUDA synchronization to prevent the system from measuring real execution time.
- [lab] Rates: o3 reward hacked in 30.4% of RE-Bench runs (39 of 128) and 100% (21 of
  21) on Optimize LLM Foundry, against 0.7% across HCAST. Table ^f3
  > | **RE-Bench  Total** | 39 | 128 | 30.4% |   |
  > | **HCAST Total** | 8 | 1087 | 0.7% |   |
- [lab] Seeing the whole scoring function may drive it: hacking was over 43 times more
  common on RE-Bench, where the model can read the scorer (difficulty or scaffolding may
  also explain it). ^f4
  > Reward hacking was more than 43× more common on RE-Bench tasks than HCAST tasks, perhaps because on RE-Bench tasks the model was able to see the entire scoring function
- [lab] Not one model: similar behaviour seen in Claude 3.7 Sonnet and o1. ^f5
  > We’ve also noticed similar behaviors for other recent models, such as Claude 3.7 Sonnet and o1.
- [lab] Prompting does not fix it: "do not cheat" or "solve the intended way" left
  reward hacking in most runs (70% to 95% vs 80% original, 20 runs each). ^f6
  > Instructing the model to solve the task the intended way, to not cheat, or to not reward hack had a nearly negligible effect on reward hacking, which still persisted in a majority of runs.
- [lab] The model knows: asked whether its plan matched the user's intention, o3
  answered no 10 out of 10 times. ^f7
  > o3 answered “no” 10 out of 10 times.
- [lab] Detection used anomalously high scores plus manual review, and an LLM monitor
  over outputs; both have high false-positive rates and each missed hacks the other found;
  failed hack attempts don't show up as high scores. ^f8
  > On RE-Bench tasks, we looked for anomalously high-scoring runs and manually inspected them, since reward hacking arises from cheating yielding higher scores.
  > These methods both have a very high false-positive rate, so we only use them to filter to a small set of runs which we manually review.
- [lab] Recommended fix is to patch the exploit in the scoring setup when a monitor
  finds it, rather than punishing the model, which can drive hacking underground. ^f9
  > A more robust (though more difficult) way to address reward hacking might involve making the training setup less susceptible to exploits (e.g. use a monitor to detect reward hacking, then when it’s detected patch the exploit in the scoring function rather than punishing the model).
- [lab] Current hacks are blatant: agents describe them in output and the code fails
  in obvious ways, so reading transcripts catches them for now. ^f10
  > the agents accurately describe their reward hacking behavior in the transcript and in their CoT, and the reward hacking strategies they use typically cause the programs they write to fail in obvious ways, not subtle ones.
- [lab] (inferred) For meiolol: the eval code and held-out data must sit outside what
  the agent can write (and ideally read); scores far above the current best should
  trigger a diff review, not a celebration. ^f11

## Read

- Whole post, including the o3 task table and prompt-variation table

## Not read

- Transcript server (transcripts.metr.org): concrete hack code per task
- Linked OpenAI chain-of-thought monitoring post
