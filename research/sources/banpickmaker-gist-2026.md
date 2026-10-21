---
title: 'BanPickMaker: Meta-Aware Cold-Start Champion Recommendation for Evolving League of Legends Drafts'
url: https://scholar.gist.ac.kr/handle/local/34486
kind: paper
commit: 
for: [frontier-pretrain]
looked: 2026-10-21
depth: skimmed (abstract only; full text behind a dCollection login)
relevance: medium
grade: D/weak
description: Yujin Kim, GIST master's thesis (2026, advisor KyungJoong Kim); LoL pick recommendation with champions as LLM-derived semantic profiles plus patch-level lane stats and rolling pro-meta features, tested on temporal and champion-level cold start
---
# BanPickMaker: Meta-Aware Cold-Start Champion Recommendation for Evolving League of Legends Drafts

Why: the only League work found that puts LLM champion profiles into a draft model and
tests unseen champions.

## Assessment

- Evidence: D for us: abstract only; master's thesis; pick recommendation in pro
  drafts, not win prediction; baselines named are frequency-based.
- Reasoning: weak (from the abstract): no id-embedding baseline named, no numbers.
- Interests: none known.
- Weigh: shows the idea has been built for League; says nothing about its size. Read
  the full text only if it becomes public.

## Findings

- [method/pretrain] Champions are represented by LLM-derived semantic profiles plus
  patch-level champion-lane statistics and causal rolling pro-meta features, so unseen
  champions can be scored. Abstract ^f1
  > BanPickMaker represents each champion using LLM-derived semantic profiles, patch-level champion-lane statistics, and causal rolling professional-meta features
- [method/pretrain] Motivation: id embeddings can't generalise to unseen champions or a
  changing meta. Abstract ^f2
  > Existing approaches often rely on champion-ID embeddings or historical interactions, limiting their ability to generalize to fully draft-unseen champions and changing metagames.
- [method/pretrain] Result claimed only against frequency-based baselines, on temporal and
  champion-level cold-start benchmarks; target is recommendation ranking, not win. Abstract ^f3
  > Experiments on temporal and champion-level cold-start benchmarks show that BanPickMaker outperforms frequency-based baselines and achieves stronger top-ranked recommendation performance.
- [method/pretrain] Checked, not there (abstract): no win or log-loss result, no
  comparison with id embeddings on seen champions, no text-only ablation. ^f4

## Read

- Abstract and record page

## Not read

- Full text (http://gist.dcollection.net/common/orgView/200001016769, login wall)
