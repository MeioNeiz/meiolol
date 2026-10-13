---
title: 'MLE-bench README: leaderboard (as of Oct 2026)'
url: https://github.com/openai/mle-bench
kind: project
commit: 507f92e1138bb6e40dac5c6ee7a6758e6424bf97
for: [agent-ml-practice]
origin: mle-bench
looked: 2026-10-13
depth: docs (README.md leaderboard and benchmarking sections)
relevance: medium
grade: A/fair
description: OpenAI's MLE-bench leaderboard table: top agents Feb-Mar 2026 at 61-64% any medal on all 75 tasks; test-set-feedback entries set apart; new submissions paused since April 2026
---
# MLE-bench README: leaderboard (as of Oct 2026)

Why: which ML-engineering agents lead now, with what models and budgets, and what the
maintainers say about comparing them. Paper itself: [[mle-bench]].

## Assessment

- Evidence: A. The benchmark's own maintained table with grading reports per entry.
- Reasoning: fair. A table; no account of what made each entry better.
- Interests: none for the table; entries are self-submitted, many closed source.
- Weigh: rankings mix budgets (12 vs 24 h), hardware and knowledge bases; read with
  [[mars-agent#^f14]].

## Findings

- [lab] Top of the main table (All, any medal %, 24 h): Famou-Agent 2.0 (Gemini-3-Pro)
  64.44 ± 1.18, AIBuildAI (Claude-Opus-4.6) 63.11 ± 0.44, MARS+ 62.67 ± 0.77, MLEvolve
  61.33 (12 h), PiEvolve 61.33; ML-Master 2.0 56.44; AIDE with o1-preview 17.12 in
  Oct 2024. `README.md` ^f1
  > | [AIBuildAI](https://github.com/aibuildai/AI-Build-AI) | Claude-Opus-4.6 |  77.27 ± 0.00 |  61.40 ± 0.88 |  46.67 ± 0.00 | 63.11 ± 0.44 | 24 | 2026-03-06 | X | ✓ |
- [lab] Entries that used test-set feedback are kept off the main table; one such
  ensemble reached 77.78%, 13 points above the best fair entry. `README.md` ^f2
  > | [Disarray](https://disarray.ai) | Ensemble (Claude-Opus-4.5, Claude-Sonnet-4.5, GPT-5.2-Codex, Gemini-3-Pro-Preview) | 90.91 ± 0.00 | 72.81 ± 0.88 | 71.11 ± 2.22 | 77.78 ± 0.44 | 24 | 2026-02-03 | [Test-set feedback]
- [lab] Submissions paused since April 2026 while the maintainers work out how to keep
  entries fair and comparable. `README.md` ^f3
  > We are currently not taking any new submissions to the leaderboard while we develop an improved process for ensuring submissions are fair and comparable.
- [lab] Maintainers require at least 3 seeds and mean ± SEM, because agents vary a lot
  even though grading is deterministic; incomplete seeds are padded with failing
  scores. `README.md` ^f4
  > Repeat each evaluation with at least 3 seeds and report the Any Medal (%) score as the mean ± one standard error of the mean. The evaluation (task and grading) itself is deterministic, but agents/LLMs can be quite high-variance!
  > Computed by padding incomplete seeds with failing scores.
- [lab] (inferred) Most top entries are closed source; of the open ones with papers
  read, MARS gives ablations; source code is marked available for few of the top five. ^f5

## Read

- README.md: leaderboard tables, footnotes, benchmarking and Lite sections.

## Not read

- PRs #118 and #119 (why test-set feedback entries were set apart); grading reports.
