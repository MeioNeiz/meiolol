---
title: 'SakanaAI/ShinkaEvolve: islands, weighted parent sampling, novelty rejection, meta summaries'
url: https://github.com/SakanaAI/ShinkaEvolve
kind: project
commit: 8adc053a2ce4511ad2ac310e004c530a73fb974a
for: [llm-experiment-agent]
looked: 2026-10-12
depth: code (README.md, docs/core_concepts.md, docs/configuration.md, shinka/core/novelty_judge.py, shinka/database/parents.py, shinka/prompts/prompts_meta.py, prompts_novelty.py)
relevance: high
grade: B/fair
description: Open-source AlphaEvolve-style program evolution from Sakana AI (ICLR 2026); SQLite program database with islands and archive, weighted parent sampling, embedding plus LLM novelty rejection, LLM meta summaries as memory
---
# SakanaAI/ShinkaEvolve: islands, weighted parent sampling, novelty rejection, meta summaries

Why: AlphaEvolve's paper leaves the program database vague; this is a readable open
implementation of the same design with the knobs exposed.

## Assessment

- Evidence: B. Created Sept 2025, ~1.4k stars, 291 forks, 28 contributors, Apache-2.0,
  release v0.0.7 (June 2026), pushed Oct 2026, large test suite (90+ test files).
  Paper accepted at ICLR 2026 per README. Used by a team that won ICFP 2025 contest.
- Reasoning: fair. Config docs explain each knob; why the defaults were chosen is in
  the paper (not read beyond the abstract).
- Interests: Sakana AI's own framework.
- Weigh: trust the mechanisms as read in code. Defaults (2 islands, archive 40, 50
  generations) are for cheap exact verifiers like circle packing; selection on a noisy
  score like our AUC would chase lucky runs unless the evaluator averages repeats.

## Findings

- [lab] Task contract: an initial program with mutable regions and an `evaluate.py`
  that returns a combined score and a correctness flag. `docs/core_concepts.md` ^f1
  > At minimum, the evaluator surfaces a `combined_score` and whether the candidate is functionally correct.
- [lab] Each generation: sample parent and inspirations from database and archive, LLM
  proposes a patch, validate, evaluate, store, then update archive, islands and
  meta-memory. `docs/core_concepts.md` ^f2
  > 1. Sample a parent or inspiration context from the database and archive
  > 6. Update archive state, island state, and optional meta-memory
- [lab] Diversity: island-local populations plus a global archive of high-value
  programs, with migration between islands every N generations (rate 0 by default, so
  islands stay separate). `docs/configuration.md` ^f3
  > | `num_islands` | `int` | `2` | Number of islands. |
  > | `migration_rate` | `float` | `0.0` | Fraction of programs migrated at migration events. |
- [lab] Dynamic islands: after N generations with no improvement (default 100), spawn
  a new island seeded from the initial, best or a random archive program.
  `docs/configuration.md` ^f4
  > | `stagnation_threshold` | `int` | `100` | No-improvement generations before spawn. |
- [lab] Parent selection options: weighted (default), power law over rank, beam search,
  plus best-of-N (always the initial program) and sequential (always the latest)
  in code. `shinka/database/parents.py` ^f5
  > class BestOfNSamplingStrategy(ParentSamplingStrategy):
  > """Sequential sampling: always returns most recent correct program."""
- [lab] Weighted parent selection: sigmoid of the score's distance from the archive
  median (scaled by MAD), times 1/(1 + children), so strong parents with few children
  are favoured: explicit exploit plus explore. `shinka/database/parents.py` ^f6
  > normalized_diff = (alpha_i - alpha_0) / scale_factor
  > h_i = 1 / (1 + n_i)
- [lab] Novelty rejection: embed the proposed code; if its cosine similarity to any
  program on the island is above a threshold (0.99 in presets), ask an LLM judge
  whether it is meaningfully different, else resample (up to 3 tries). Saves
  evaluations on near-duplicates. `shinka/core/novelty_judge.py` ^f7
  > if max_similarity <= self.similarity_threshold:
  > is_novel, explanation, cost = self.check_llm_novelty(
- [lab] The novelty judge counts hyperparameter changes as novel and ignores renames,
  formatting and comments. `shinka/prompts/prompts_novelty.py` ^f8
  > 5. **Hyperparameter changes**: Different hyperparameters that could lead to different performance characteristics
  > - Variable name changes
- [lab] Memory of past experiments: every 10 generations a meta step summarises each
  new program, folds them into a running insights scratchpad (what worked, what did
  not, with scores), then writes up to 5 recommendations fed to later mutations.
  `docs/configuration.md`, `shinka/prompts/prompts_meta.py` ^f9
  > | `meta_rec_interval` | `Optional[int]` | `10` | Generation interval for meta recommendations. |
  > ## Ineffective Approaches
  > Make sure to incorporate the previous insights into the new insights.
- [lab] The insights step separates analysis from advice: it must cite specific
  programs and scores and not recommend; recommendations come in a third step and may
  not touch the evaluation code. `shinka/prompts/prompts_meta.py` ^f10
  > Do not make recommendations for the next steps. ONLY PERFORM THE ANALYSIS.
  > DO NOT RECOMMEND CHANGING THE EVALUATION CODE.
- [lab] Cost controls: a USD cap on API spend, and a UCB bandit across mutation models
  rewarded by observed improvement, optionally weighted to prefer cheaper models.
  `docs/configuration.md`, `docs/core_concepts.md` ^f11
  > | `max_api_costs` | `Optional[float]` | `None` | API budget cap in USD; stops new submissions at cap. |
  > Optional cost-aware blending to prefer cheaper models when quality is close
- [lab] Budget presets: small 20 generations, one evaluation at a time, one model;
  medium 50 generations, 4 parallel evaluations; large 300 generations.
  `docs/configuration.md` ^f12
  > num_generations: 20
  > num_generations: 300
- [lab] Mutation mixes diff patches, full rewrites and crossover of two programs
  (default probabilities 0.6, 0.3, 0.1). `docs/configuration.md` ^f13
  > | `patch_types` | `List[str]` | `['diff', 'full', 'cross']` | Patch formats; supports `diff`, `full`, `cross`. |
- [lab] Results go to a SQLite database plus code snapshots and diffs per candidate,
  inspected in a web UI or notebooks; agent skills exist to set up, run and inspect
  from Claude Code or Codex. `docs/core_concepts.md`, `README.md` ^f14
  > Persisted program records and metrics
  > Added [agent skills](https://sakanaai.github.io/ShinkaEvolve/agentic_usage/) for using `shinka` within coding agents (Claude Code, Codex, etc.)
- [lab] Checked, not there: no repeated evaluation or noise handling in parent
  selection or the archive; a single `combined_score` per program is taken as true.
  (inferred from parents.py and config) ^f15

## Read

- `docs/core_concepts.md`, `docs/configuration.md`: in full.
- `shinka/core/novelty_judge.py`, `shinka/prompts/prompts_novelty.py`,
  `shinka/prompts/prompts_meta.py`: in full. `shinka/database/parents.py`: weighted
  and power-law strategies.

## Not read

- `shinka/database/islands.py`, `dbase.py`: migration and archive replacement details.
- `skills/` (shinka-setup, shinka-run, shinka-inspect): how an outer coding agent drives
  it; may matter if we wrap our loop the same way.
- The paper body (ablations of each component).
