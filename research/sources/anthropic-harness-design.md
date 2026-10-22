---
title: 'Anthropic Engineering: Harness design for long-running application development (Mar 2026)'
url: https://www.anthropic.com/engineering/harness-design-long-running-apps
kind: article
commit: 
for: [ui-tooling]
looked: 2026-10-22
depth: skimmed (intro, frontend design section, evaluator, simplifying)
relevance: high
grade: B/strong
description: Anthropic Labs: a separate evaluator agent with Playwright, written grading criteria and few-shot calibration improves frontend design; self-evaluation praises mediocre work; out of the box Claude is a poor QA agent
---
# Anthropic Engineering: Harness design for long-running application development

Why: first-hand report on LLM agents judging UI with screenshots in the loop.

## Assessment

- Evidence: B. First-hand engineering report from the model maker, several runs and an
  ablation; no numbers on design quality, judged by the author's taste.
- Reasoning: strong. Admits limits (poor QA out of the box, criteria wording steers
  output, evaluator worth it only at the edge of model capability).
- Interests: vendor (Anthropic; also the maker of the model writing this note).
- Weigh: trust the qualitative lessons; agrees with uicrit-2024 (criteria and examples
  matter; generic critique is weak).

## Findings

- [web/qa] Agents grading their own work praise it, worst on subjective work like design.
  Intro ^f1
  > When asked to evaluate work they've produced, agents tend to respond by confidently praising the work—even when, to a human observer, the quality is obviously mediocre.
- [web/qa] A separate evaluator, tuned to be sceptical, is more tractable than a
  self-critical generator. Intro ^f2
  > But tuning a standalone evaluator to be skeptical turns out to be far more tractable than making a generator critical of its own work
- [web/qa] Written criteria turn "is it good?" into gradable questions. Frontend design ^f3
  > "Is this design beautiful?" is hard to answer consistently, but "does this follow our principles for good design?" gives Claude something concrete to grade against.
- [web/qa] Evaluator calibrated with few-shot examples with score breakdowns. ^f4
  > I calibrated the evaluator using few-shot examples with detailed score breakdowns.
- [web/qa] Evaluator used Playwright MCP to navigate, screenshot and study the live page
  before scoring. ^f5
  > In practice, the evaluator would navigate the page on its own, screenshotting and carefully studying the implementation before producing its assessment.
- [web/qa] Out of the box Claude is a poor QA agent: talks itself out of real issues,
  tests superficially; small layout issues still slipped through after tuning. ^f6
  > Out of the box, Claude is a poor QA agent.
  > small layout issues, interactions that felt unintuitive in places
- [web/qa] Wording of criteria steers the output ("museum quality" made designs converge).
  ^f7
  > The wording of the criteria steered the generator in ways I didn't fully anticipate.
- [web/qa] (inferred) For meiolol: an agent review pass is worth having as a separate
  session with a written meiolol rubric and a couple of scored example pages, after the
  deterministic checks, never as the gate for overflow or contrast. ^f8

## Read

- Intro, frontend design, evaluator, simplifying sections

## Not read

- Full DAW and RetroForge walkthroughs, appendix spec
