---
status: answered
priority: soon
area: stats
parent: frontier-experiments
tags: [method, method/pretrain]
description: Can self-supervised pretraining over drafts (masked picks, contrastive) or entity embeddings from text (LLM embeddings of champion kits and patch notes) improve win prediction or rare-champion estimates in MOBAs or similar domains?
---
# Can self-supervised pretraining over drafts (masked picks, contrastive) or entity embeddings from text (LLM embeddings of champion kits and patch notes) improve win prediction or rare-champion estimates in MOBAs or similar domains?

Feeds: docs/plan/lab-frontier.md (gpu-box experiment programme), parent [[frontier-experiments]]

## Answer

Mostly no, with one narrow yes. Where each entity has plenty of data, the input
representation (one-hot, random vector, text embedding, image) makes no measurable
difference, and pretraining a known-entity model across more data gave nothing over
random init (C1). Content (text, kit, stat profiles) pays only where id data is thin
or absent, and the gain fades as the id fills in (C2). Even there, a few days of the
new piece's own results, or a handful of usage statistics, beat text embeddings (C3);
text alone buys day-zero transfer at a large cost against ids (C4). Small sentence
encoders (e5, bge) are as good as big LLMs for embedding entries (C5). LLMs as direct
predictors don't beat fitted models or markets: they restate the public numbers (C6).

Self-supervised pretraining on the same rows helps weak nets most; contrastive is no
better than masked reconstruction, and target-aware objectives (win loss plus
reconstruction) are best (C7). In draft models masking and auxiliary heads exist, but
no source measures their win gain over scratch on held-out games, and LoLDraftAI found
auxiliaries helped only with less data (C8). Industry MOBA drafters (JueWu, OpenAI
Five) use plain id-based win predictors on huge data (C9). Counting buffs and nerfs in
patch notes doesn't reliably predict win-rate moves (C10); no source tests patch-note
text as a feature.

That fits ours: the d8 stat-pretrained prior (docs/model.md "Pretrained champion-role
embeddings") gave -0.24 milli-nats overall, not detected, and -0.76 on games with a
pick under 200 fit games (31% of fold games); in nets it added nothing. So for meiolol
content belongs in the cold-start slice (new champions, reworks, thin champion-roles)
as a content-predicted prior mean with id fallback, not as a replacement for ids (C11);
masked-pick pretraining of the set net is unlikely to clear noise (C12). Search
saturated: the last 5 of 20 searches found 0-1 new sources.

## Claims

- C1: With plenty of data per entity, card representation (one-hot, random, text, image) makes no difference to accuracy; it matters only for unseen entities; multi-set pretraining then fine-tuning on a known set gave nothing over random init. for: [[bertram-card-representations-2024#^f1]], [[bertram-card-representations-2024#^f2]], [[bertram-card-representations-2024#^f5]], [[dropoutnet-2017#^f3]]
- C2: Content or attribute priors help in proportion to how thin the id data is and fade as data grows. for: [[agarwal-chen-2009-rlfm#^f8]], [[matano-2018-augmented-apm#^f5]], [[autoelicit-2025#^f3]], [[mtg-deck-strength-2026#^f3]]
- C3: For unseen pieces, a few days of their own outcomes or a few usage statistics beat text embeddings. for: [[mtg-deck-strength-2026#^f3]], [[mtg-deck-strength-2026#^f4]], [[bertram-card-representations-2024#^f4]]
- C4: Text plus structured features with no ids give day-zero transfer (MTG picks 51-60% on unseen sets) at a large cost against id models where ids are learnable (66-71%). for: [[draftfm-2026#^f1]], [[draftfm-2026#^f3]], [[draftfm-2026#^f6]], [[banpickmaker-gist-2026#^f1]]
- C5: For embedding table entries, e5 or bge-class sentence encoders match or beat 7B decoder LLMs; for low-diversity categorical strings language models add little. for: [[grinsztajn-string-entries-2023#^f1]], [[grinsztajn-string-entries-2023#^f3]], [[draftfm-2026#^f2]]
- C6: LLMs used directly as predictors don't beat fitted models or markets; frontier agents restated the market (r 0.97-0.99) and none beat its Brier score; GPT-4o drafting fell below hand ratings. for: [[worldcup-llm-forecast-2026#^f2]], [[worldcup-llm-forecast-2026#^f3]], [[draftfm-2026#^f4]], [[autoelicit-2025#^f6]]
- C7: Same-data pretraining helps most for weak nets and less for strong ones; contrastive is no better than masked reconstruction; target-aware objectives are best. for: [[rubachev-tabular-pretrain-2022#^f2]], [[rubachev-tabular-pretrain-2022#^f3]], [[rubachev-tabular-pretrain-2022#^f5]], [[risingballer-2024#^f4]]
- C8: Draft models use masking and auxiliary heads, but no source measures a win gain from them against scratch on held-out games; LoLDraftAI's auxiliaries helped only with less data. for: [[loldraftai#^f15]], [[loldraftai#^f14]], [[draftrec-2022#^f13]], [[risingballer-2024#^f6]], [[nba2vec-2023#^f4]]
- C9: Industry MOBA drafting (JueWu, OpenAI Five) scores drafts with id-based win predictors trained on huge data, no text or pretrained hero vectors. for: [[juewu-draft-2020#^f1]], [[openai-five-2019#^f4]]
- C10: Counting a champion's buffs and nerfs does not reliably predict its win-rate change. for: [[kica-claypool-lol-patches#^f4]]
- C11 (inferred): For meiolol, text or kit content belongs in the cold-start slice as a content-predicted prior mean with id fallback (RLFM, DropoutNet), expected under ~0.3 milli-nats overall and larger on rare-pick games. from: C1, C2, C3, C4
- C12 (inferred): Masked-pick or contrastive pretraining of the set net is unlikely to clear noise; if tried, use the target-aware form. from: C7, C8

## Disagreements

- Pretraining gains: RisingBALLER 11-13% MSE (C, overlapping data, weak baseline) and
  Rubachev's significant gains for plain MLPs (B) vs Bertram's no gain over random init
  on a known set (B) and our 0a null in nets. Baseline strength differs; a target-aware
  run on our set net would settle it for us.
- Text for new pieces: BanPickMaker beats frequency baselines (D, abstract only) and
  DraftFM transfers well (C) vs Rigaux's text-only no better than linear (C).
  Different targets (picks vs win); a leave-champion-out test on our games settles it.

## Open

- Modeller: is a text embedding of a champion's kit any better than our d8 stat
  embedding as a prior for a champion with no games (leave-one-champion-out)?
- Critic: is any gain beyond the first days after a release or rework? Rigaux says
  four days of data close the gap.
- Patch notes: does a parsed signed-change feature (stat, size) beat a mean-reversion
  prior for the first days of a patch? Untested anywhere (C10 only says counts fail).
- LLM prior: on post-cutoff patches, does an LLM's guess of a new champion's strength
  beat the role mean? No source; contamination makes older patches useless.
- Cost: text embedding of ~170 kits is minutes on CPU; masked-pick multi-task on the
  set net is hours on the 3080; nulls on either close the topic.
