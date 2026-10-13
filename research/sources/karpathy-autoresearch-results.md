---
title: 'Karpathy on X: autoresearch tuned nanochat for ~2 days, ~20 kept changes transferred'
url: https://x.com/karpathy/status/2031135152349524125
kind: thread
commit:
for: [agent-ml-practice, llm-experiment-agent]
looked: 2026-10-13
depth: skimmed (post text as shown logged out, truncated)
relevance: medium
grade: B/fair
description: Karpathy's 9 Mar 2026 report of a ~2-day autoresearch run on nanochat depth 12: ~700 changes tried, ~20 kept, all additive and transferring to depth 24, Time to GPT-2 2.02 h to 1.80 h
---
# Karpathy on X: autoresearch tuned nanochat for ~2 days, ~20 kept changes transferred

Why: the reported outcome of the autoresearch loop ([[karpathy-autoresearch]]), and
whether its single-seed keeps were real.

## Assessment

- Evidence: B. First-hand report by a recognised expert, with an external check (keeps
  re-tested at a larger model size and on the nanochat leaderboard metric). One run, no
  seed repeats reported; the post is cut off logged out, so the list of changes is not
  read.
- Reasoning: fair. He tested transfer and additivity himself; says nothing on how many
  of the ~700 discards were noise-rejected real gains.
- Interests: his own project; enthusiastic tone.
- Weigh: shows a greedy single-seed keep works when kept effects are large next to run
  noise; does not show it works near the noise floor (see [[lucky-runs]]).

## Findings

- [lab] A ~2-day run on a depth-12 model kept ~20 changes out of about 700 tried; all ~20
  were additive and transferred to depth-24 models. ^f1
  > It found ~20 changes that improved the validation loss. I tested these changes yesterday and all of them were additive and transferred to larger (depth=24) models.
  > as it worked through approx. 700 changes autonomously is wild.
- [lab] Stacked, they cut nanochat's "Time to GPT-2" from 2.02 to 1.80 hours (~11%), a
  metric separate from the val loss the loop optimised. ^f2
  > Stacking up all of these changes, today I measured that the leaderboard's "Time to GPT-2" drops from 2.02 hours to 1.80 hours (~11% improvement)
- [lab] Keep rate about 3% (20 of 700): most proposals are discarded, so throughput of
  cheap fixed-budget runs carries the method. (inferred) ^f3
- [lab] The agent planned from the sequence of earlier results, per Karpathy. ^f4
  > It really looked at the sequence of results of experiments and used that to plan the next ones.
- [lab] Checked, not there: no repeated seeds or confirmation runs on the kept changes
  before the transfer test; the human did the confirmation afterwards. ^f5

## Read

- The post text as rendered logged out (cut at "It noticed an oversight that my para").

## Not read

- The rest of the post (list of changes) and replies; the 7 Mar announcement post.
