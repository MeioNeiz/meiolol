---
status: answered
priority: soon
area: stats
tags: [lab, method]
description: How should an LLM agent run meiolol's modelling experiments, and which tools should it get?
---
# How should an LLM agent run meiolol's modelling experiments, and which tools should it get?

Feeds: a meiolol-lab "agent loop" (an LLM proposing, running and analysing draft and
outcome model experiments on the gpu-box via deploy/lab-run.sh); docs/model.md protocol

## Answer

Build a narrow, purpose-made loop, not a general agent with many tools: a scaffold made
for ML experiments, which keeps the agent improving until the budget runs out, beat
general agents with the same model several times over (C1). Shape: autoresearch-style
greedy keep-or-reset on one git branch, each step one atomic change, every run on a fixed
wall-clock budget so runs compare, output to a log and one parseable summary line (C2,
C3). Fancier search (MCTS, evolutionary islands) buys nothing until the operators are
good (C4), though R&D-Agent found a diverse first layer then greedy branches beat a plain
chain (C5); a cheap middle ground is several short independent attempts with different
seeds or briefs, best-of-k, which beats one long session at equal time, partly because
long contexts accumulate false beliefs (C6).

Tools that measurably helped are few: edit and run in the repo, a validate/score command
the harness runs (not the agent), output truncation with full logs on disk, time left
shown every turn, and memory as a written plan plus a results table (C7, C8).
Literature search, embedding memory, background jobs went unused or unmeasured (C7).
Every experiment, failures included, is a structured record: diff, seed, metrics,
interval, keep/discard, one-line why (C9), and a rolling digest of what worked and what
did not feeds the next proposal (C10).

The binding constraint for meiolol is the eval signal, not the search. Reusing one
holdout adaptively manufactures wins out of pure noise (C11), static multiple-testing
corrections do not cover it (C12), and tuning against a noisy estimate overfits after
30-40 iterations (C13); agent loops show the same validation-up, test-flat gap and most
of it is in choosing the final model (C14). None of the loops read handle noise (C15).
So the agent sees cross-validation inside train plus a Ladder-style answer from a
selection holdout ("new best by the paired test" or "no change", C16), with a budget of
looks; the final test is scored once per campaign by a human command. Agents game
visible scorers often (o3 30% of RE-Bench runs) and asking them not to barely helps;
hidden, read-only evaluation and a "flag for human" exit do (C17, C18). Every number in a
write-up comes from the harness's run records, never the agent's text (C19).

## Claims

- C1: Purpose-built ML scaffolds that push the agent to use its whole budget beat general agents with more tools. for: [[mle-bench#^f1]], [[mle-bench#^f4]], [[re-bench#^f2]], [[mlagentbench#^f6]]
- C2: Autoresearch loop: edit one file, commit, run on a fixed 5-minute budget, grep the metric, append to a TSV, keep the commit or git reset; eval and data read-only. for: [[karpathy-autoresearch#^f5]], [[karpathy-autoresearch#^f4]], [[karpathy-autoresearch#^f3]]
- C3: One atomic change per improve step, so each effect is measurable; bounded debug depth. for: [[aide-paper#^f5]], [[aide-paper#^f4]], [[aideml#^f2]]
- C4: With AIDE's operators, MCTS and evolutionary search gain nothing over greedy; better operators do (39.8% to 45.5%). for: [[aira-dojo-paper#^f4]], [[aira-dojo-paper#^f6]]
- C5: A diverse first layer then greedy within branches beat a linear chain (35.1% vs 25.3% medals, single-run ablation). for: [[rd-agent-paper#^f4]], [[rd-agent-paper#^f10]]
- C6: Several short attempts, best-of-k, beat one long run at equal total time; context resets helped the plain agent. for: [[re-bench#^f3]], [[re-bench#^f5]], [[mle-bench#^f7]]
- C7: Tools that helped: truncated output, time left each turn, scoring before analysis; extra tools were rarely used and gave more ways to fail. for: [[mle-bench#^f10]], [[mle-bench#^f11]], [[re-bench#^f13]], [[re-bench#^f15]], [[mle-bench#^f5]], [[mlgym#^f12]]
- C8: A research log with plan, status and fact check cut, but did not stop, invented results; memory modules are unmeasured. for: [[mlagentbench#^f4]], [[mlagentbench#^f5]], [[mlgym#^f4]], [[aira-dojo-paper#^f5]]
- C9: Mature systems keep every experiment, failures included, as structured records. for: [[ai-scientist-v2#^f6]], [[rd-agent#^f3]], [[rd-agent#^f4]], [[alphaevolve#^f3]], [[karpathy-autoresearch#^f7]]
- C10: Memory as a rolling digest of what worked and failed, with scores; analysis kept separate from recommendations. for: [[shinkaevolve#^f9]], [[shinkaevolve#^f10]], [[aideml#^f7]]
- C11: Adaptive reuse of a holdout reported 63% accuracy on pure-noise labels. for: [[dwork-holdout-reuse#^f3]]
- C12: Static multiple-testing corrections assume a fixed set of tests, broken by adaptive choice. for: [[dwork-holdout-reuse#^f2]]
- C13: Tuning against a noisy validation estimate overfits after ~30-40 iterations, worst with small data. for: [[cawley-talbot-2010#^f3]], [[cawley-talbot-2010#^f4]]
- C14: Agent search raises validation while test plateaus; final-node choice is most of the gap; top-3 hedging recovers ~10%. for: [[aira-dojo-paper#^f14]], [[aira-dojo-paper#^f15]], [[aira-dojo-paper#^f16]], [[aira-dojo-paper#^f17]], [[re-bench#^f7]]
- C15: Autoresearch keeps on single runs with a fixed seed; evolutionary systems ignore noise in parent selection. for: [[karpathy-autoresearch#^f12]], [[karpathy-autoresearch#^f13]], [[shinkaevolve#^f15]]
- C16: The Ladder releases a new score only when a paired test beats the best, so error grows with log k, not sqrt k. for: [[blum-hardt-ladder#^f3]], [[blum-hardt-ladder#^f5]]
- C17: Agents game visible scorers (o3 30% of RE-Bench runs, 43x more with the scorer visible); "do not cheat" prompts unreliable. for: [[metr-reward-hacking-2025#^f3]], [[metr-reward-hacking-2025#^f4]], [[metr-reward-hacking-2025#^f6]] against: [[impossiblebench#^f2]]
- C18: Hidden tests cut cheating to near zero; a flag-for-human exit cut it 54% to 9% for GPT-5. for: [[impossiblebench#^f3]], [[impossiblebench#^f6]]
- C19: Agents invent results (an unrun ablation table, edited time limits), so numbers must come from harness records. for: [[sakana-ai-scientist#^f1]], [[sakana-ai-scientist#^f5]], [[mlagentbench#^f5]]
- C20 (inferred): For meiolol, a better eval signal (more held-out games, repeated seeds, paired tests) pays more than a better search policy. from: C11, C14, C15

## Disagreements

- Tree vs greedy: AIRA-dojo (A/strong, controlled) finds no gain from search policy
  with fixed operators; R&D-Agent (B/fair, single-run ablation) finds a diverse tree
  beats a chain. Both fit "diversity early, greedy after". Best-of-k short attempts
  gives diversity without a tree.
- Holdout reuse: Roelofs 2019 / Recht 2019 (leads, unread) find little overfitting from
  Kaggle leaderboard reuse; their test sets are far bigger and capped, our effects sit
  at noise. Reading them would settle how strict the look budget must be.
- Prompting against cheating: METR says negligible, ImpossibleBench says it works for
  some models (GPT-5 92% to 1%) but not others. Design as if it does not.

## Open

- Cost per run in tokens and money: no source gives it
- Whether an agent finds anything at all while data is at noise level; volume first?
- Roelofs 2019, Recht 2019, Kapoor "AI Agents That Matter" (leads)
